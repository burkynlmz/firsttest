import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models.dart'; // Modellerimizi çağırdık

class SoruEkrani extends StatefulWidget {
  final int surecId;
  const SoruEkrani({super.key, required this.surecId});

  @override
  State<SoruEkrani> createState() => _SoruEkraniState();
}

class _SoruEkraniState extends State<SoruEkrani> {
  final DatabaseService _dbService = DatabaseService();

  // --- STATE DEĞİŞKENLERİ ---
  bool _yukleniyor = true;
  Soru? _aktifSoru;       // Ekranda gösterilen soru nesnesi
  String? _sonucMetni;    // Süreç bittiyse gösterilecek sonuç yazısı

  @override
  void initState() {
    super.initState();
    _baslangicSorusunuYukle();
  }

  // 1. Sürecin ilk sorusunu bulup yükler
  Future<void> _baslangicSorusunuYukle() async {
    final surec = await _dbService.getSurecById(widget.surecId);
    
    if (surec != null) {
      await _soruyuGetir(surec.baslangicSoruId);
    } else {
      setState(() {
        _yukleniyor = false;
        _sonucMetni = "Hata: Süreç bulunamadı.";
      });
    }
  }

  // 2. ID'si verilen soruyu veritabanından çeker
  Future<void> _soruyuGetir(int soruId) async {
    setState(() => _yukleniyor = true);
    
    final soru = await _dbService.getQuestionById(soruId);
    
    setState(() {
      _aktifSoru = soru;
      _yukleniyor = false;
    });
  }

  // 3. Kullanıcının verdiği cevabı işler
  Future<void> _cevapVer(bool evetSecildi) async {
    if (_aktifSoru == null) return;

    // Modeller sayesinde mantık ne kadar sadeleşti:
    // Null kontrolü ('?') sayesinde 0 veya null gelmesi fark etmez, güvenlidir.
    final sonrakiSoruId = evetSecildi ? _aktifSoru!.evetSoruId : _aktifSoru!.hayirSoruId;

    if (sonrakiSoruId != null) {
      // Sonraki soruya geç
      await _soruyuGetir(sonrakiSoruId);
    } else {
      // Süreç bitti, Sonuç Ekranına geç
      await _sonucuIsle(_aktifSoru!.sonucTipi, _aktifSoru!.ilgiliBelgeId);
    }
  }

  // 4. Sonuç metnini oluşturur ve veritabanına kaydeder
  Future<void> _sonucuIsle(String? sonucTipi, int? belgeId) async {
    setState(() => _yukleniyor = true);

    String metin = 'Süreç tamamlandı. Sonuç: $sonucTipi';
    String? belgeAdi = 'Yok';

    // Eğer belge varsa detaylarını çek
    if (belgeId != null) {
      final belge = await _dbService.getDocumentById(belgeId);
      if (belge != null) {
        belgeAdi = belge.ad;
        metin += "\n\n📄 GEREKLİ BELGE\n------------------\n${belge.ad}\n\n📝 NOT\n${belge.not ?? 'Açıklama yok.'}";
      }
    }

    // Oturumu Kaydet
    final yeniOturum = Oturum(
      surecId: widget.surecId,
      soruId: _aktifSoru?.id ?? 0,
      verilenCevap: "Tip: $sonucTipi, Belge: $belgeAdi",
      cevapTarihi: DateTime.now().toIso8601String(),
      aktifMi: 0, // 0: Tamamlandı
    );

    await _dbService.insertSession(yeniOturum);

    // Ekrana sonucu bas
    setState(() {
      _aktifSoru = null; // Soruyu ekrandan kaldır
      _sonucMetni = metin;
      _yukleniyor = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Karar Verme Süreci'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: _buildBody(),
      ),
    );
  }

  // UI kodunu parçalara ayırdık, okuması daha kolay
  Widget _buildBody() {
    if (_yukleniyor) {
      return const Center(child: CircularProgressIndicator());
    }

    // Durum 1: Sonuç gösteriliyor
    if (_sonucMetni != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
            const SizedBox(height: 20),
            Text(
              _sonucMetni!,
              style: const TextStyle(fontSize: 18, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              child: const Text('ANA EKRANA DÖN'),
            )
          ],
        ),
      );
    }

    // Durum 2: Soru gösteriliyor
    if (_aktifSoru != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Soru #${_aktifSoru!.id}",
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 15),
          Text(
            _aktifSoru!.metin,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 50),
          ElevatedButton(
            onPressed: () => _cevapVer(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(vertical: 18),
            ),
            child: const Text('EVET', style: TextStyle(fontSize: 18, color: Colors.white)),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => _cevapVer(false),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(vertical: 18),
            ),
            child: const Text('HAYIR', style: TextStyle(fontSize: 18, color: Colors.white)),
          ),
        ],
      );
    }

    return const Center(child: Text("Beklenmedik bir hata oluştu."));
  }
}