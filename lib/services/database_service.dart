import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';
import 'package:flutter/services.dart';

class DatabaseService {

  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {

    // 1. Veritabanı klasör yolunu al.
    var databasesPath = await getDatabasesPath();
    var path = join(databasesPath, "burokrasi_yoneticisi.db");
    
    // 2. Dosyanın cihazda varlığını kontrol et.
    var exists = await databaseExists(path);

    if (!exists) {
      // 3. Eğer dosya yoksa (Uygulamanın ilk çalışması):
      
      print("Veritabanı (${basename(path)}) bulunamadı, assets'ten kopyalanıyor...");

      try {
        // Asset'teki dosyayı ByteData olarak yükle.
        ByteData data = await rootBundle.load(join("assets", "burokrasi_yoneticisi.db"));
        List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

        // Veritabanı klasörü yoksa oluştur.
        await Directory(dirname(path)).create(recursive: true);

        // Dosyayı hedef klasöre kopyala ve yaz.
        await File(path).writeAsBytes(bytes, flush: true);
        
        print("Veritabanı kopyalama tamamlandı.");
        
      } catch (e) {
        print("Veritabanı kopyalama hatası: $e");
      }
    } else {
      print("Veritabanı zaten mevcut. Kopyalama atlandı.");
    }

    // 4. Veritabanını aç.
    // Bu aşamada artık "version" kontrolü ve onCreate/onUpgrade metotları çalışır.
    _database = await openDatabase(
      path,
      version: 1, // Dosyayı ilk kopyalamada versiyon 1 olarak açar.
      onCreate: (db, version) {
        // ÖNEMLİ: Statik tabloları (SORULAR, BELGELER, SUREC) BURAYA YAZMA!
        // Onlar zaten kopyalanan .db dosyasında var.
        
        // Sadece **dinamik olarak** kullanıcı tarafından doldurulacak tabloları (örneğin oturum kayıtları) buraya ekle.
        db.execute(
          "CREATE TABLE KULLANICI_OTURUMU(id INTEGER PRIMARY KEY, tarih TEXT, sonuc TEXT)",
        );
        print("Dinamik tablolar (varsa) oluşturuldu.");
      },
    );
    return _database!;

  }

  // KULLANICI_OTURUMU tablosuna yeni bir sonuç kaydı ekler
  Future<int> insertSession(Map<String, dynamic> row) async {
    Database db = await database;
    return await db.insert('KULLANICI_OTURUMU', row);
  }

  // KULLANICI_OTURUMU tablosundaki tüm kayıtları getirir
  Future<List<Map<String, dynamic>>> getHistorySessions() async {
    Database db = await database;
    return await db.query('KULLANICI_OTURUMU', orderBy: 'Cevap_Tarihi DESC');
  }

  // Tüm süreçlerin (SUREC_ID ve Baslik) listesini getirir.
  Future<List<Map<String, dynamic>>> getAllSurec() async {
    Database db = await database;
    return await db.query('SUREC', columns: ['Surec_ID', 'Baslik']);
  }

  // Belirli bir sürecin detaylarını (özellikle Başlangıç_Soru_ID'yi) getirir.
  Future<Map<String, dynamic>?> getSurecById(int surecId) async {
    Database db = await database;
    List<Map<String, dynamic>> result = await db.query(
      'SUREC',
      where: 'Surec_ID = ?',
      whereArgs: [surecId],
    );
    return result.isNotEmpty ? result.first : null;
  }

  // Belirli bir Soru_ID'ye ait metinleri ve sonraki adım bilgilerini getirir.
  Future<Map<String, dynamic>?> getQuestionById(int soruId) async {
    Database db = await database;
    List<Map<String, dynamic>> result = await db.query(
      'SORULAR',
      where: 'Soru_ID = ?',
      whereArgs: [soruId],
    );
    return result.isNotEmpty ? result.first : null;
  }

  /* BU FONKSİYONUN DÖNDÜRDÜĞÜ VERİLER ÖNEMLİ: yukarıdaki sorular tablosu
  - Soru_Metni: Kullanıcıya gösterilecek soru.
  - Ileri_Soru_ID_Evet / Hayir: Kullanıcının cevabına göre sonraki Soru_ID (veya Sonuc_Tipi ise 0/null).
  - Belge_ID_Gerekiyorsa: Eğer soru bir belgeye yönlendiriyorsa, Belge_ID'si.
  - Sonuc_Tipi: İşlemin bittiğini ve bir sonuca ulaşıldığını belirtir (örn. "BelgeGerekli", "IslemBitti").
  */

  // Belirli bir Belge_ID'ye ait tüm detayları (Ad, Açıklama, Gerekli Yer) getirir.
  Future<Map<String, dynamic>?> getDocumentById(int belgeId) async {
    Database db = await database;
    List<Map<String, dynamic>> result = await db.query(
      'BELGELER',
      where: 'Belge_ID = ?',
      whereArgs: [belgeId],
    );
    return result.isNotEmpty ? result.first : null;
  }

  
}
