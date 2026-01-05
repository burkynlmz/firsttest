import 'package:flutter/material.dart';
import 'services/database_service.dart';
import 'soru_ekrani.dart'; 
import 'gecmis_oturumlar_ekrani.dart';
import 'models.dart';

class SurecListesiEkrani extends StatefulWidget {
  const SurecListesiEkrani({super.key});

  @override
  State<SurecListesiEkrani> createState() => _SurecListesiEkraniState();
}

class _SurecListesiEkraniState extends State<SurecListesiEkrani> {
  final DatabaseService dbService = DatabaseService();
  
  List<Surec> _tumSurecler = [];
  List<Surec> _filtrelenmisSurecler = [];
  bool _yukleniyor = true;
  final TextEditingController _aramaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _verileriYukle();
  }

  // Verileri çek ve FAVORİLERE GÖRE SIRALA
  Future<void> _verileriYukle() async {
    List<Surec> surecler = await dbService.getAllSurec();
    
    // YENİ: Sıralama Mantığı
    // a ve b iki süreçtir. Eğer a favori ise (true), listenin başına (-1) geçer.
    surecler.sort((a, b) {
      if (a.favoriMi == b.favoriMi) {
        return a.id.compareTo(b.id); // İkisi de aynıysa ID'ye göre sırala
      }
      return a.favoriMi ? -1 : 1; 
    });

    setState(() {
      _tumSurecler = surecler;
      // Eğer arama kutusu doluysa, o kelimeye göre tekrar filtrele, değilse hepsini göster
      if (_aramaController.text.isNotEmpty) {
        _aramaYap(_aramaController.text);
      } else {
        _filtrelenmisSurecler = surecler;
      }
      _yukleniyor = false;
    });
  }

  // YENİ FONKSİYON: Favori Durumunu Değiştir
  Future<void> _favoriDegistir(Surec surec) async {
    // 1. Veritabanını güncelle
    await dbService.toggleSurecFavori(surec.id, !surec.favoriMi);
    
    // 2. Listeyi yenile (Bu sayede sıralama güncellenir ve kalp rengi değişir)
    await _verileriYukle();
  }

  void _aramaYap(String arananKelime) {
    setState(() {
      if (arananKelime.isEmpty) {
        _filtrelenmisSurecler = _tumSurecler;
      } else {
        _filtrelenmisSurecler = _tumSurecler.where((surec) {
          final surecAdi = surec.baslik.toLowerCase();
          final aranan = arananKelime.toLowerCase();
          return surecAdi.contains(aranan);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _aramaController,
          onChanged: _aramaYap, 
          style: const TextStyle(color: Colors.white),
          cursorColor: Colors.white,
          decoration: InputDecoration(
            hintText: 'Süreç Ara... (Örn: Pasaport)',
            hintStyle: const TextStyle(color: Colors.white70),
            border: InputBorder.none,
            icon: const Icon(Icons.search, color: Colors.white),
            suffixIcon: _aramaController.text.isNotEmpty 
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white),
                    onPressed: () {
                      _aramaController.clear();
                      _aramaYap('');
                      // Klavye kapansın istersen: FocusScope.of(context).unfocus();
                    },
                  )
                : null,
          ),
        ),
        backgroundColor: Colors.blueGrey,
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            tooltip: 'Geçmiş Oturumlar',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GecmisOturumlarEkrani(), 
                ),
              );
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_yukleniyor) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filtrelenmisSurecler.isEmpty) {
      return const Center(child: Text("Süreç bulunamadı."));
    }

    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: _filtrelenmisSurecler.length,
      itemBuilder: (context, index) {
        final surec = _filtrelenmisSurecler[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: ListTile(
            // Sol taraftaki ikon
            leading: const Icon(Icons.assignment, color: Colors.blueGrey),
            
            title: Text(surec.baslik, style: const TextStyle(fontWeight: FontWeight.bold)),
            
            // YENİ: Sağ tarafa Kalp Butonu ekledik
            trailing: IconButton(
              icon: Icon(
                surec.favoriMi ? Icons.favorite : Icons.favorite_border,
                color: surec.favoriMi ? Colors.red : Colors.grey,
              ),
              onPressed: () => _favoriDegistir(surec),
            ),
            
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SoruEkrani(surecId: surec.id),
                ),
              );
            },
          ),
        );
      },
    );
  }
}