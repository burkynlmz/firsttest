import 'package:flutter/material.dart';
import 'services/database_service.dart'; 

class GecmisOturumlarEkrani extends StatelessWidget {
  final DatabaseService dbService = DatabaseService();

  GecmisOturumlarEkrani({super.key});

  // Tarih formatını daha okunaklı hale getiren yardımcı fonksiyon
  String formatTarih(String isoTarih) {
    // Veritabanında TEXT olarak kayıtlı ISO tarihini DateTime nesnesine dönüştür
    try {
      final DateTime dateTime = DateTime.parse(isoTarih);

      return "${dateTime.day}. ${dateTime.month}. ${dateTime.year} - ${dateTime.hour}:${dateTime.minute}";
    } catch (e) {
      return "Geçersiz Tarih";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tamamlanan Süreçler'),
        backgroundColor: Colors.teal,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(

        future: dbService.getHistorySessions(), 
        builder: (context, snapshot) {
          
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(child: Text('Veri yüklenirken hata oluştu: ${snapshot.error}'));
          }

          final List<Map<String, dynamic>> oturumlar = snapshot.data ?? [];
          
          if (oturumlar.isEmpty) {
            return const Center(child: Text('Tamamlanmış süreç kaydı bulunmamaktadır.'));
          }
          
          return ListView.builder(
            itemCount: oturumlar.length,
            itemBuilder: (context, index) {
              final oturum = oturumlar[index];
              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: ListTile(
                  // 'Verilen_Cevap' sütununu gösteriyoruz
                  title: Text(oturum['Verilen_Cevap'] ?? 'Sonuç Bilgisi Yok', style: const TextStyle(fontWeight: FontWeight.bold)), 
                  // 'Cevap_Tarihi' sütununu formatlayıp gösteriyoruz
                  subtitle: Text('Tarih: ${formatTarih(oturum['Cevap_Tarihi'] ?? '')}'), 
                  trailing: Text('Süreç ID: ${oturum['Surec_ID']}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}