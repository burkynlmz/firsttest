import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfService {
  
  // PDF oluşturup yazdırma/paylaşma ekranını açan fonksiyon
  Future<void> raporOlustur({
    required String sonucTipi,
    required String? belgeAdi,
    required String? belgeNotu,
  }) async {
    
    // 1. Türkçe karakter destekleyen fontu yükle
    final font = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();

    // 2. PDF dokümanını oluştur
    final doc = pw.Document();

    // 3. Sayfa tasarımı (Sayfa ekle)
    doc.addPage(
      pw.Page(
        pageTheme: pw.PageTheme(
          theme: pw.ThemeData.withFont(
            base: font,
            bold: boldFont,
          ),
        ),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Başlık
              pw.Header(
                level: 0,
                child: pw.Text('Bürokrasi Yönetimi - Sonuç Raporu', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              ),
              
              pw.SizedBox(height: 20),

              // Tarih Bilgisi
              pw.Text('Tarih: ${DateTime.now().day}.${DateTime.now().month}.${DateTime.now().year}', style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
              
              pw.Divider(),
              pw.SizedBox(height: 20),

              // Sonuç Bilgisi
              pw.Text('İşlem Sonucu:', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Text(sonucTipi, style: const pw.TextStyle(fontSize: 16)),
              
              pw.SizedBox(height: 30),

              // Eğer belge varsa belge bilgilerini yazdır
              if (belgeAdi != null && belgeAdi != "Yok") ...[
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.blueGrey),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                       pw.Text('📄 GEREKLİ BELGE', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue)),
                       pw.SizedBox(height: 5),
                       pw.Text(belgeAdi, style: const pw.TextStyle(fontSize: 18)),
                       pw.SizedBox(height: 10),
                       pw.Text('📝 NOT / AÇIKLAMA:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                       pw.Text(belgeNotu ?? 'Açıklama bulunmamaktadır.', style: const pw.TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
              ],
              
              pw.Spacer(),
              
              // Alt Bilgi (Footer)
              pw.Text('Bu belge Bürokrasi Yöneticisi uygulaması tarafından oluşturulmuştur.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
            ],
          );
        },
      ),
    );

    // 4. Yazdırma/Paylaşma penceresini aç
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'sonuc_raporu.pdf', // Dosya adı
    );
  }
}