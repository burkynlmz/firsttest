import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

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

    String path = join(await getDatabasesPath());
    String dbPath = join(path, 'burokrasi_yoneticisi.db');

    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await _onCreate(db, version);
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    
    await db.execute('''
      CREATE TABLE SUREC (
        Surec_ID INTEGER PRIMARY KEY AUTOINCREMENT,
        Baslik TEXT NOT NULL,
        Baslangic_Soru_ID INTEGER NOT NULL
      );
    ''');
  }

  Future<int> insertExample(Map<String, dynamic> row) async {
    Database db = await database;
    return await db.insert('example_table', row);
  }

  Future<List<Map<String, dynamic>>> queryAllExamples() async {
    Database db = await database;
    return await db.query('example_table');
  }
}
