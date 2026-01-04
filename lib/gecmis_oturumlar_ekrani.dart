import 'package:flutter/material.dart';
import 'services/database_service.dart';
import 'models.dart';

class GecmisOturumlarEkrani extends StatelessWidget {
  final DatabaseService dbService = DatabaseService();

  GecmisOturumlarEkrani({super.key});

  String formatTarih(String isoTarih) {
    try {
      final DateTime dateTime = DateTime.parse(isoTarih);
      // Basit bir formatlama: 16.12.2025 - 14:30
      return "${dateTime.day}.${dateTime.month}.${dateTime.year} - ${dateTime.hour.toString().padLeft(2,'0')}:${dateTime.minute.toString().padLeft(2,'0')}";
    } catch (e) {
      return "Tarih Hatası";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Geçmiş İşlemler'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      // FutureBuilder List<Oturum> bekliyor
      body: FutureBuilder<List<Oturum>>(
        future: dbService.getHistorySessions(), 
        builder: (context, snapshot) {
          
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(child: Text('Veri yüklenirken hata oluştu.'));
          }

          final oturumlar = snapshot.data ?? [];
          
          if (oturumlar.isEmpty) {
            return const Center(child: Text('Henüz tamamlanmış bir işlem yok.'));
          }
          
          return ListView.builder(
            itemCount: oturumlar.length,
            itemBuilder: (context, index) {
              final oturum = oturumlar[index];
              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.teal),
                  // Nesne tabanlı erişim:
                  title: Text(
                    oturum.verilenCevap, 
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ), 
                  subtitle: Text('Tarih: ${formatTarih(oturum.cevapTarihi)}'), 
                  trailing: Text('ID: ${oturum.surecId}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}