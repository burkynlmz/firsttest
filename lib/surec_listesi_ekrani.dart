import 'package:flutter/material.dart';
import 'services/database_service.dart';
import 'soru_ekrani.dart'; 
import 'gecmis_oturumlar_ekrani.dart';
import 'models.dart'; // Modelleri eklemeyi unutmuyoruz

class SurecListesiEkrani extends StatelessWidget {
  final DatabaseService dbService = DatabaseService();

  SurecListesiEkrani({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bürokrasi Yönetimi'),
        centerTitle: true,
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
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
      // FutureBuilder artık List<Surec> bekliyor
      body: FutureBuilder<List<Surec>>(
        future: dbService.getAllSurec(), 
        builder: (context, snapshot) {
          
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}'));
          }

          final surecler = snapshot.data ?? [];
          
          if (surecler.isEmpty) {
            return const Center(child: Text('Süreç bulunamadı.'));
          }
          
          return ListView.builder(
            itemCount: surecler.length,
            itemBuilder: (context, index) {
              final surec = surecler[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: ListTile(
                  leading: const Icon(Icons.assignment, color: Colors.blueGrey),
                  // Artık surec['Baslik'] değil, surec.baslik diyoruz (Hata yapma şansı yok!)
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
        },
      ),
    );
  }
}