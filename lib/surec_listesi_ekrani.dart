import 'package:flutter/material.dart';
import 'services/database_service.dart';
import 'soru_ekrani.dart'; 
import 'gecmis_oturumlar_ekrani.dart';

class SurecListesiEkrani extends StatelessWidget {

  final DatabaseService dbService = DatabaseService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bürokrasi Yönetimi'),
        backgroundColor: Colors.blueGrey,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
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
      body: FutureBuilder<List<Map<String, dynamic>>>(
        // 1. Database'den tüm süreçleri çek
        future: dbService.getAllSurec(), 
        builder: (context, snapshot) {
          
          // Veri çekilirken yükleniyor göstergesi
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          // Hata kontrolü
          if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}'));
          }

          // Veri başarılı ve dolu ise listele
          final List<Map<String, dynamic>> surecler = snapshot.data ?? [];
          
          if (surecler.isEmpty) {
            return const Center(child: Text('Veritabanında süreç bulunamadı.'));
          }
          
          return ListView.builder(
            itemCount: surecler.length,
            itemBuilder: (context, index) {
              final surec = surecler[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: ListTile(
                  title: Text(surec['Baslik'] ?? 'Başlıksız Süreç', style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // 2. Süreç seçildiğinde Soru Ekranına geçiş yap
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        // Seçilen sürecin ID'sini SoruEkranına taşıyoruz
                        builder: (context) => SoruEkrani(surecId: surec['Surec_ID']),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}