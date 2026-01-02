import 'package:flutter/material.dart';
import '/services/database_service.dart'; 

class SoruEkrani extends StatefulWidget {
  final int surecId;
  
  // Sürecin başlangıcında bize Süreç ID'si verilecek
  const SoruEkrani({super.key, required this.surecId});

  @override
  State<SoruEkrani> createState() => _SoruEkraniState();
}

class _SoruEkraniState extends State<SoruEkrani> {
  final DatabaseService dbService = DatabaseService();
  
  // Hangi soruda olduğumuzu tutan ID.
  int? mevcutSoruId; 
  Map<String, dynamic>? mevcutSoru;

  @override
  void initState() {
    super.initState();
    // Ekran açıldığında başlangıç sorusunu yükle.
    _baslangicSorusunuYukle();
  }

  // Süreç ID'sine göre başlangıç sorusunu bulup yükleyen ana fonksiyon
  Future<void> _baslangicSorusunuYukle() async {
    // Süreç ID'si ile Baslangic_Soru_ID'yi bul
    final surecData = await dbService.getSurecById(widget.surecId);
    
    if (surecData != null && surecData['Baslangic_Soru_ID'] != null) {
      int baslangicSoruId = surecData['Baslangic_Soru_ID'];
      
      // Başlangıç Soru ID'si ile soruyu çek
      await _soruyuYukle(baslangicSoruId);
    } else {
      // Hata durumu: Başlangıç sorusu bulunamadı
      setState(() {
        mevcutSoru = {'Soru_Metni': 'Başlangıç bilgisi eksik.', 'Sonuc_Tipi': 'HATA'};
      });
    }
  }
  
  // Verilen ID'ye göre soruyu veritabanından çeker ve state'i günceller
  Future<void> _soruyuYukle(int soruId) async {
    final soruData = await dbService.getQuestionById(soruId);
    setState(() {
      mevcutSoruId = soruId;
      mevcutSoru = soruData;
    });
  }

  // --- CEVAP İŞLEME MANTIĞI ---
  Future<void> _cevapVer(bool cevap) async{
    if (mevcutSoru == null) return;

       
    // Sonraki ID'yi veritabanından dinamik olarak çek
    final dynamic rawSonrakiId = cevap 
      ? mevcutSoru!['Cevap_Evet_Soru_ID'] 
      : mevcutSoru!['Cevap_Hayir_Soru_ID'];

    // print('Kullanıcı Cevabı: ${cevap ? "EVET" : "HAYIR"}');
    // print('Veritabanından Gelen HAM ID: $rawSonrakiId (Türü: ${rawSonrakiId.runtimeType})');

    // Çekilen değeri tam sayıya (int) çevir.
    final int? sonrakiId = (rawSonrakiId != null) 
          ? int.tryParse(rawSonrakiId.toString()) 
          : null;

    // print('İşlenen (int) Sonraki ID: $sonrakiId');
    int sId = sonrakiId ?? 0;
    debugPrint("Sonraki Soru ID'si: $sId");
    // Karar Mantığı
    if (sId > 0) {
      // Bir sonraki soruya geç
      await _soruyuYukle(sId); 
    } else {
      // SONUÇ AŞAMASI
      debugPrint("Sonucu göster çağrılıyor ${mevcutSoru!['Sonuc_Tipi']} , ${mevcutSoru!['Ilgili_Belge_ID']}");
      await _sonucuGoster(mevcutSoru!['Sonuc_Tipi'], mevcutSoru!['Ilgili_Belge_ID']);
    }
  }
  
  Future<void> _sonucuGoster(String? sonucTipi, int? belgeId) async {
    String sonucMetni = 'Süreç tamamlandı. Sonuç: $sonucTipi.';
    String? belgeAd = 'Yok';
    debugPrint("Sonucu göster girildi. Sonuç Tipi: $sonucTipi, Belge ID: $belgeId");
    // Eğer Belge ID'si varsa, belge detaylarını çek
    if (belgeId != null && belgeId > 0) {
      final belgeData = await dbService.getDocumentById(belgeId);
      if (belgeData != null) {
        belgeAd = belgeData['Belge_Ad'];
        // Sonuç metnine belge detaylarını ekle
        sonucMetni += "\n\n— GEREKLİ BELGE —\nBelge Adı: ${belgeAd}\nAçıklama: ${belgeData['Belge_Aciklama'] ?? 'Belge açıklaması bulunamadı.'}";
      }
    }
    // KULLANICI_OTURUMU tablosuna kaydı yap
    final kayitBasarili = await _oturumKaydiYap(sonucTipi, belgeAd);

    if (kayitBasarili) {
       sonucMetni += "\n\n(Oturum başarıyla kaydedildi.)";
    } else {
       sonucMetni += "\n\n(UYARI: Oturum kaydedilemedi!)";
    }

    // Ekranı Sonuç Mesajı ile güncelle
    setState(() {
      mevcutSoru = {
        'Soru_Metni': sonucMetni, 
        'Sonuc_Tipi': sonucTipi
      };
      mevcutSoruId = null; // Butonları kaldırmak ve sonucu göstermek için
    });
  }

  // Kullanıcı Oturumunu kaydeder
  Future<bool> _oturumKaydiYap(String? sonucTipi, String? belgeAd) async {
    try {
      // Kaydedilecek veriler
      Map<String, dynamic> row = {
        'Surec_ID': widget.surecId, // İlgili Süreç ID'si
        'Soru_ID': mevcutSoruId, // eN SOn ulaşılan soru ID'si
        'Verilen_Cevap': "Tip: $sonucTipi, Belge: ${belgeAd ?? 'Yok'}", //cevap metni ve sonuç bilgisi kaydeder
        'Cevap_Tarihi': DateTime.now().toIso8601String(), // cevap tarihi kaydet
        'Aktif_Mi': 0 // Süreç tamamlandı
      };
      
      await dbService.insertSession(row); // DatabaseService'deki fonksiyon çağrılıyor
      return true;
    } catch (e) {
      print("Oturum kaydı hatası: $e");
      return false;
    }
  }

  // --- WIDGET YAPISI ---
  @override
  Widget build(BuildContext context) {
    if (mevcutSoru == null) {
      return  Scaffold(
        appBar: AppBar(title: Text('Soru Yükleniyor...')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Sorunun metni veya sonuç mesajı
    final String metin = mevcutSoru!['Soru_Metni'] ?? 'Soru metni bulunamadı.';
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Karar Verme'),
        backgroundColor: Colors.indigo,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Soru Metni
            Text(
              mevcutSoruId != null ? "Soru #${mevcutSoruId!}:" : "Sonuç:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w300, color: Colors.indigo[800]),
            ),
            const SizedBox(height: 10),
            Text(
              metin,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 50),
            
            // Cevap butonları sadece soru varsa görünür
            if (mevcutSoruId != null) 
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    onPressed: () => _cevapVer(true), // Evet cevabı
                    child: const Text('EVET', style: TextStyle(fontSize: 18)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 15)),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => _cevapVer(false), // Hayır cevabı
                    child: const Text('HAYIR', style: TextStyle(fontSize: 18)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 15)),
                  ),
                ],
              ),
              
            if (mevcutSoruId == null)
              ElevatedButton(
                onPressed: () => Navigator.pop(context), // Ana listeye dön
                child: const Text('ANA EKRANA DÖN', style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
              ),
          ],
        ),
      ),
    );
  }
}