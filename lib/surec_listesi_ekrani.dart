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
  
  // --- STATE DEĞİŞKENLERİ ---
  List<Surec> _tumSurecler = [];        // Veritabanından gelen tüm liste
  List<Surec> _filtrelenmisSurecler = []; // Ekranda gösterilen (aranan) liste
  bool _yukleniyor = true;              // Veri yükleniyor mu?
  final TextEditingController _aramaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _verileriYukle();
  }

  // Veritabanından verileri çekip hafızaya alıyoruz
  Future<void> _verileriYukle() async {
    final surecler = await dbService.getAllSurec();
    setState(() {
      _tumSurecler = surecler;
      _filtrelenmisSurecler = surecler; // Başlangıçta hepsi görünür
      _yukleniyor = false;
    });
  }

  // Arama kutusuna her harf yazıldığında çalışır
  void _aramaYap(String arananKelime) {
    setState(() {
      if (arananKelime.isEmpty) {
        // Arama kutusu boşsa hepsini göster
        _filtrelenmisSurecler = _tumSurecler;
      } else {
        // Arama kutusu doluysa filtrele
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
        // Başlık yerine Arama Kutusu koyuyoruz
        title: TextField(
          controller: _aramaController,
          onChanged: _aramaYap, // Yazı değiştikçe filtrele
          style: const TextStyle(color: Colors.white),
          cursorColor: Colors.white,
          decoration: InputDecoration(
            hintText: 'Süreç Ara... (Örn: Tadilat İzni)',
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
            icon: Icon(Icons.search, color: Colors.white),
            suffixIcon: _aramaController.text.isNotEmpty 
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white),
                    onPressed: () {
                      _aramaController.clear();
                      _aramaYap(''); // Listeyi sıfırla
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 60, color: Colors.grey),
            const SizedBox(height: 10),
            Text(
              _tumSurecler.isEmpty 
                  ? 'Kayıtlı süreç bulunamadı.' 
                  : 'Aradığınız kriterde süreç bulunamadı.',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, // YENİ: Kaydırınca klavyeyi kapat
      itemCount: _filtrelenmisSurecler.length,
      itemBuilder: (context, index) {
        final surec = _filtrelenmisSurecler[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: ListTile(
            leading: const Icon(Icons.assignment, color: Colors.blueGrey),
            title: Text(surec.baslik, style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
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