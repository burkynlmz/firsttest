import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/database_service.dart';
import '../services/pdf_service.dart';
import '../models.dart';

class SoruEkrani extends StatefulWidget {
  final int surecId;
  const SoruEkrani({super.key, required this.surecId});

  @override
  State<SoruEkrani> createState() => _SoruEkraniState();
}

class _SoruEkraniState extends State<SoruEkrani> {
  final DatabaseService _dbService = DatabaseService();
  final PdfService _pdfService = PdfService();

  // --- STATE DEĞİŞKENLERİ ---
  bool _yukleniyor = true;
  Soru? _aktifSoru;
  String? _sonucMetni;
  Surec? _aktifSurec;

  // PDF için veriler
  String? _pdfSonucTipi;
  String? _pdfBelgeAdi;
  String? _pdfBelgeNotu;

  @override
  void initState() {
    super.initState();
    _baslangicSorusunuYukle();
  }

  Future<void> _baslangicSorusunuYukle() async {
    final surec = await _dbService.getSurecById(widget.surecId);
    
    if (surec != null) {
      setState(() {
        _aktifSurec = surec;
      });
      await _soruyuGetir(surec.baslangicSoruId);
    } else {
      setState(() {
        _yukleniyor = false;
        _sonucMetni = "Hata: Süreç bulunamadı.";
      });
    }
  }

  Future<void> _soruyuGetir(int soruId) async {
    setState(() => _yukleniyor = true);
    final soru = await _dbService.getQuestionById(soruId);
    setState(() {
      _aktifSoru = soru;
      _yukleniyor = false;
    });
  }

  // --- DÜZELTME 1: Mantık Hatası Giderildi ---
  Future<void> _cevapVer(bool evetSecildi) async {
    if (_aktifSoru == null) return;

    final sonrakiSoruId = evetSecildi ? _aktifSoru!.evetSoruId : _aktifSoru!.hayirSoruId;

    if (sonrakiSoruId != null) {
      // Sonraki soruya geç
      await _soruyuGetir(sonrakiSoruId);
    } else {
      // SÜREÇ BİTTİ
      // Eğer EVET seçildiyse ve süreç bittiyse bu bir Başarıdır (ONAY).
      // Eğer HAYIR seçildiyse veritabanındaki sonucu (Muhtemelen RED) kullanırız.
      String nihaiSonuc = evetSecildi ? "ONAY" : (_aktifSoru!.sonucTipi ?? "BİLİNMİYOR");
      
      await _sonucuIsle(nihaiSonuc, _aktifSoru!.ilgiliBelgeId);
    }
  }

  Future<void> _sonucuIsle(String sonucTipi, int? belgeId) async {
    setState(() => _yukleniyor = true);

    String metin = 'Süreç tamamlandı. Sonuç: $sonucTipi';
    String? belgeAdi = 'Yok';
    String? belgeNotu;

    if (belgeId != null) {
      final belge = await _dbService.getDocumentById(belgeId);
      if (belge != null) {
        belgeAdi = belge.ad;
        belgeNotu = belge.not;
        metin += "\n\n📄 GEREKLİ BELGE\n------------------\n${belge.ad}\n\n📝 NOT\n${belge.not ?? 'Açıklama yok.'}";
      }
    }

    final yeniOturum = Oturum(
      surecId: widget.surecId,
      soruId: _aktifSoru?.id ?? 0,
      verilenCevap: "Tip: $sonucTipi, Belge: $belgeAdi",
      cevapTarihi: DateTime.now().toIso8601String(),
      aktifMi: 0,
    );

    await _dbService.insertSession(yeniOturum);

    setState(() {
      _aktifSoru = null;
      _sonucMetni = metin;
      _pdfSonucTipi = sonucTipi; // Düzeltilmiş sonucu PDF'e gönderiyoruz
      _pdfBelgeAdi = belgeAdi;
      _pdfBelgeNotu = belgeNotu;
      _yukleniyor = false;
    });
  }

  Future<void> _haritayiAc(String aramaTerimi) async {
    final String googleMapsUrl = "https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(aramaTerimi)}";
    final Uri url = Uri.parse(googleMapsUrl);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Link açılamadı: $url');
      }
    } catch (e) {
      debugPrint("Harita hatası: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Harita uygulaması açılamadı.")),
      );
    }
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

  Widget _buildBody() {
    if (_yukleniyor) {
      return const Center(child: CircularProgressIndicator());
    }

    // DURUM 1: SONUÇ GÖSTERİLİYOR
    if (_sonucMetni != null) {
      
      // --- DÜZELTME 2: İkon ve Renk Mantığı ---
      bool basariliMi = _pdfSonucTipi == "ONAY";
      Color sonucRengi = basariliMi ? Colors.green : Colors.red;
      IconData sonucIkonu = basariliMi ? Icons.check_circle_outline : Icons.cancel_outlined;

      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(sonucIkonu, size: 80, color: sonucRengi),
              const SizedBox(height: 20),
              Text(
                _sonucMetni!,
                style: const TextStyle(fontSize: 18, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),

              // PDF Butonu
              ElevatedButton.icon(
                onPressed: () {
                  _pdfService.raporOlustur(
                    sonucTipi: _pdfSonucTipi!,
                    belgeAdi: _pdfBelgeAdi,
                    belgeNotu: _pdfBelgeNotu,
                  );
                },
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('SONUCU PDF OLARAK İNDİR'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  minimumSize: const Size(250, 45),
                ),
              ),
              
              const SizedBox(height: 15),

              // Harita Butonu
              if (_aktifSurec?.aramaTerimi != null)
                ElevatedButton.icon(
                  onPressed: () => _haritayiAc(_aktifSurec!.aramaTerimi!),
                  icon: const Icon(Icons.map),
                  label: const Text('EN YAKIN KURUMU BUL'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    minimumSize: const Size(250, 45),
                  ),
                ),

              const SizedBox(height: 30),

              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                   padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
                child: const Text('ANA EKRANA DÖN'),
              )
            ],
          ),
        ),
      );
    }

    // DURUM 2: SORU GÖSTERİLİYOR
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