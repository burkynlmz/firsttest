import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import '../models.dart'; // Model dosyamızı import ediyoruz (yoluna dikkat et)

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
    var databasesPath = await getDatabasesPath();
    var path = join(databasesPath, "burokrasi_yoneticisi.db");
    
    // Veritabanı var mı kontrol et
    var exists = await databaseExists(path);

    if (!exists) {
      print("Veritabanı bulunamadı, assets'ten kopyalanıyor...");
      try {
        ByteData data = await rootBundle.load(join("assets", "burokrasi_yoneticisi.db"));
        List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        
        await Directory(dirname(path)).create(recursive: true);
        await File(path).writeAsBytes(bytes, flush: true);
        print("Kopyalama başarılı.");
      } catch (e) {
        print("Veritabanı kopyalama hatası: $e");
      }
    }
    
    return await openDatabase(path, version: 1);
  }

  // --- ARTIK NESNE (OBJECT) DÖNDÜREN FONKSİYONLAR ---

  // Tüm süreçleri liste olarak getirir (Surec Listesi)
  Future<List<Surec>> getAllSurec() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('SUREC');
    
    // Gelen her bir Map'i Surec nesnesine çeviriyoruz
    return List.generate(maps.length, (i) => Surec.fromMap(maps[i]));
  }

  // ID'ye göre tek bir Soru getirir
  Future<Soru?> getQuestionById(int soruId) async {
    Database db = await database;
    List<Map<String, dynamic>> result = await db.query(
      'SORULAR',
      where: 'Soru_ID = ?',
      whereArgs: [soruId],
    );
    
    if (result.isNotEmpty) {
      return Soru.fromMap(result.first);
    }
    return null;
  }

  // Başlangıç sorusunu bulmak için Süreç detayını getirir
  Future<Surec?> getSurecById(int surecId) async {
    Database db = await database;
    List<Map<String, dynamic>> result = await db.query(
      'SUREC',
      where: 'Surec_ID = ?',
      whereArgs: [surecId],
    );
    return result.isNotEmpty ? Surec.fromMap(result.first) : null;
  }

  // ID'ye göre Belge getirir
  Future<Belge?> getDocumentById(int belgeId) async {
    Database db = await database;
    List<Map<String, dynamic>> result = await db.query(
      'BELGELER',
      where: 'Belge_ID = ?',
      whereArgs: [belgeId],
    );
    return result.isNotEmpty ? Belge.fromMap(result.first) : null;
  }

  // Yeni bir oturum kaydeder
  // Artık parametre olarak Map değil, Oturum nesnesi alıyoruz. Hata yapma şansımız kalmıyor.
  Future<int> insertSession(Oturum oturum) async {
    Database db = await database;
    return await db.insert('KULLANICI_OTURUMU', oturum.toMap());
  }

  // Geçmiş oturumları getirir
  Future<List<Oturum>> getHistorySessions() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('KULLANICI_OTURUMU', orderBy: 'Cevap_Tarihi DESC');
    return List.generate(maps.length, (i) => Oturum.fromMap(maps[i]));
  }
}