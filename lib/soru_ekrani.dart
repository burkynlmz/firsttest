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

  // SEPET: Toplanan Belgelerin ID'leri
  final Set<int> _toplananBelgeIdleri = {}; 
  
  // Sonuç ekranı için listeler
  List<Belge> _finalBelgeListesi = [];
  Map<int, bool> _belgeTikDurumlari = {};

  // PDF Verisi
  String? _pdfSonucTipi;

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

  Future<void> _cevapVer(bool evetSecildi) async {
    if (_aktifSoru == null) return;

    // EVET denildiyse ve belge varsa sepete at
    if (evetSecildi && _aktifSoru!.ilgiliBelgeId != null) {
      _toplananBelgeIdleri.add(_aktifSoru!.ilgiliBelgeId!);
    }

    final sonrakiSoruId = evetSecildi ? _aktifSoru!.evetSoruId : _aktifSoru!.hayirSoruId;

    if (sonrakiSoruId != null) {
      await _soruyuGetir(sonrakiSoruId);
    } else {
      String nihaiSonuc = evetSecildi ? "ONAY" : (_aktifSoru!.sonucTipi ?? "BİLİNMİYOR");
      await _sonucuIsle(nihaiSonuc);
    }
  }

  Future<void> _sonucuIsle(String sonucTipi) async {
    setState(() => _yukleniyor = true);

    String metin = 'Süreç tamamlandı. Sonuç: $sonucTipi';
    
    List<Belge> belgeler = [];
    for (int id in _toplananBelgeIdleri) {
      final b = await _dbService.getDocumentById(id);
      if (b != null) {
        belgeler.add(b);
        bool tikliMi = await _dbService.getBelgeDurumu(widget.surecId, b.id);
        _belgeTikDurumlari[b.id] = tikliMi;
      }
    }

    if (belgeler.isNotEmpty) {
      metin += "\n\n(Toplam ${belgeler.length} adet gerekli belge bulundu)";
    }

    final yeniOturum = Oturum(
      surecId: widget.surecId,
      soruId: _aktifSoru?.id ?? 0,
      verilenCevap: "Sonuç: $sonucTipi, Belge Sayısı: ${belgeler.length}",
      cevapTarihi: DateTime.now().toIso8601String(),
      aktifMi: 0,
    );
    await _dbService.insertSession(yeniOturum);

    setState(() {
      _aktifSoru = null;
      _sonucMetni = metin;
      _pdfSonucTipi = sonucTipi;
      _finalBelgeListesi = belgeler;
      _yukleniyor = false;
    });
  }

  Future<void> _checklistDegistir(int belgeId, bool? yeniDeger) async {
    if (yeniDeger == null) return;
    await _dbService.toggleBelgeDurumu(widget.surecId, belgeId, yeniDeger);
    setState(() {
      _belgeTikDurumlari[belgeId] = yeniDeger;
    });
  }

  // --- YENİ: AKILLI KONUM BULUCU ---
  // Listeyi tarar, tiklenmemiş ilk belgenin yerini döndürür.
  // Hepsi tikliyse sürecin ana yerini döndürür.
  String? _hedefKonumuBul() {
    // 1. Önce eksik belgeleri kontrol et
    for (var belge in _finalBelgeListesi) {
      bool tikli = _belgeTikDurumlari[belge.id] ?? false;
      // Eğer belge tiklenmemişse VE bir arama terimi varsa
      if (!tikli && belge.aramaTerimi != null) {
        return belge.aramaTerimi;
      }
    }
    // 2. Eksik belge yoksa ana kurumun yerini döndür
    return _aktifSurec?.aramaTerimi;
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Harita açılamadı.")));
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

    // SONUÇ EKRANI
    if (_sonucMetni != null) {
      bool basariliMi = _pdfSonucTipi == "ONAY";
      Color sonucRengi = basariliMi ? Colors.green : Colors.red;
      IconData sonucIkonu = basariliMi ? Icons.check_circle_outline : Icons.cancel_outlined;

      // Akıllı konum bulucuyu çalıştır
      String? hedefKonum = _hedefKonumuBul();
      
      // Buton yazısını hazırla
      String butonYazisi = "EN YAKIN KURUMU BUL";
      if (hedefKonum != null && _finalBelgeListesi.isNotEmpty && hedefKonum != _aktifSurec?.aramaTerimi) {
        // Eğer belge için arama yapıyorsak ismini yazalım
        butonYazisi = "EN YAKIN ${hedefKonum.toUpperCase()} BUL";
      }

      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(sonucIkonu, size: 80, color: sonucRengi),
              const SizedBox(height: 20),
              Text(
                "Süreç Tamamlandı: $_pdfSonucTipi",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: sonucRengi),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // CHECKLIST
              if (_finalBelgeListesi.isNotEmpty)
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  margin: const EdgeInsets.only(bottom: 20),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 10, bottom: 10),
                          child: Text("GEREKLİ BELGELER LİSTESİ", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                        ),
                        ..._finalBelgeListesi.map((belge) {
                          bool tikli = _belgeTikDurumlari[belge.id] ?? false;
                          return CheckboxListTile(
                            title: Text(
                              belge.ad,
                              style: TextStyle(
                                decoration: tikli ? TextDecoration.lineThrough : null,
                                color: tikli ? Colors.grey : Colors.black,
                              ),
                            ),
                            subtitle: Text(belge.not ?? ""),
                            value: tikli,
                            activeColor: Colors.green,
                            onChanged: (val) => _checklistDegistir(belge.id, val),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                )
              else 
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text("Bu işlem için herhangi bir belge gerekmemektedir.", style: TextStyle(color: Colors.grey)),
                ),

              // PDF Butonu
              if (_finalBelgeListesi.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: () {
                     String adlar = _finalBelgeListesi.map((b) => "- ${b.ad}").join("\n");
                     String notlar = _finalBelgeListesi.map((b) => "${b.ad}: ${b.not ?? '-'}").join("\n");
                    _pdfService.raporOlustur(
                      sonucTipi: _pdfSonucTipi!,
                      belgeAdi: adlar,
                      belgeNotu: notlar,
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

              // AKILLI HARİTA BUTONU
              if (hedefKonum != null)
                ElevatedButton.icon(
                  onPressed: () => _haritayiAc(hedefKonum),
                  icon: const Icon(Icons.map),
                  label: Text(butonYazisi), // Dinamik yazı
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

    // SORU EKRANI
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