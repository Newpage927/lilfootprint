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
    // 建立一張表，欄位有：id, 類型(type), 數值(value), 時間(time), 備註(note)
    // type 例如: "poop", "milk", "temp"
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

  // --- 新增紀錄 ---
  // --- 修改後的 createRecord (支援指定時間) ---
  // 如果傳入 customTime，就用傳入的；否則用當下時間
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

  // --- 讀取所有紀錄 (最新的在最上面) ---
  Future<List<Map<String, dynamic>>> readAllRecords() async {
    final db = await instance.database;
    return await db.query('records', orderBy: 'time DESC');
  }
  Future<double?> getLatestTemperature() async {
    final db = await instance.database;
    
    // 查詢 health_temp 類型，依時間倒序排列，只抓第 1 筆
    final result = await db.query(
      'records',
      where: 'type = ?',
      whereArgs: ['health_temp'],
      orderBy: 'time DESC',
      limit: 1,
    );

    if (result.isNotEmpty) {
      // 資料庫存的是字串 "38.5°C"，我們要去掉 "°C" 並轉成數字
      String valueStr = result.first['value'] as String; // 例如 "38.5°C"
      valueStr = valueStr.replaceAll('°C', '').trim();   // 變成 "38.5"
      return double.tryParse(valueStr);
    }
    return null; // 如果沒量過體溫，回傳 null
  }
  // --- 刪除紀錄 ---
  Future<int> deleteRecord(int id) async {
    final db = await instance.database;
    return await db.delete('records', where: 'id = ?', whereArgs: [id]);
  }
}