import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('baby_records.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        value TEXT,
        time TEXT NOT NULL,
        note TEXT
      )
    ''');
  }

  Future<int> createRecord(String type, String value, String note, {DateTime? customTime}) async {
    final db = await instance.database;
    final record = {
      'type': type,
      'value': value,
      'note': note,
      'time': (customTime ?? DateTime.now()).toIso8601String(), 
    };
    return await db.insert('records', record);
  }

  Future<List<Map<String, dynamic>>> readAllRecords() async {
    final db = await instance.database;
    return await db.query('records', orderBy: 'time DESC');
  }
  Future<double?> getLatestTemperature() async {
    final db = await instance.database;
    
    final result = await db.query(
      'records',
      where: 'type = ?',
      whereArgs: ['health_temp'],
      orderBy: 'time DESC',
      limit: 1,
    );

    if (result.isNotEmpty) {
      String valueStr = result.first['value'] as String;
      valueStr = valueStr.replaceAll('°C', '').trim();
    }
    return null;
  }
  Future<int> deleteRecord(int id) async {
    final db = await instance.database;
    return await db.delete('records', where: 'id = ?', whereArgs: [id]);
  }
}