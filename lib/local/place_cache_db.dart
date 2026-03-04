import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// 本地緩存數據庫類
/// 用於存儲 API 返回的地點數據，實現離線優先的讀取策略
/// 注意：Web 平台不支持 SQLite，將跳過緩存功能
class PlaceCacheDB {
  static Database? _db;

  /// 獲取數據庫路徑（跨平台）
  static Future<String> _getDatabasePath() async {
    // Android（與其他行動平台）使用標準資料庫路徑
    return join(await getDatabasesPath(), 'places_cache.db');
  }

  /// 獲取數據庫實例（單例模式）
  static Future<Database?> get db async {
    if (_db != null) return _db!;
    _db = await _init();
    return _db;
  }

  /// 初始化數據庫
  static Future<Database> _init() async {
    final path = await _getDatabasePath();

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE places (
            id TEXT PRIMARY KEY,
            category TEXT,
            city TEXT,
            lat REAL,
            lng REAL,
            json TEXT
          )
        ''');
        
        // 創建索引以加速查詢
        await db.execute('''
          CREATE INDEX idx_places_location ON places(lat, lng)
        ''');
        await db.execute('''
          CREATE INDEX idx_places_category ON places(category)
        ''');
      },
    );
  }

  /// 保存或更新地點數據（批量操作）
  static Future<void> upsertPlaces(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;

    final database = await db;
    if (database == null) return;
    
    final batch = database.batch();

    for (final item in items) {
      batch.insert(
        'places',
        {
          'id': item['id']?.toString() ?? '',
          'category': item['category']?.toString() ?? '',
          'city': item['city']?.toString() ?? '',
          'lat': (item['lat'] as num?)?.toDouble() ?? 0.0,
          'lng': (item['lng'] as num?)?.toDouble() ?? 0.0,
          'json': jsonEncode(item),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// 根據 bbox 和 category 查詢緩存的地點
  static Future<List<Map<String, dynamic>>> queryPlaces({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    required List<String> categories,
  }) async {
    if (categories.isEmpty) return [];

    final database = await db;
    if (database == null) return [];

    final catPlaceholders = List.filled(categories.length, '?').join(',');

    final result = await database.rawQuery(
      '''
      SELECT json FROM places
      WHERE lat BETWEEN ? AND ?
        AND lng BETWEEN ? AND ?
        AND category IN ($catPlaceholders)
      ''',
      [
        minLat,
        maxLat,
        minLng,
        maxLng,
        ...categories,
      ],
    );

    return result
        .map((r) => jsonDecode(r['json'] as String) as Map<String, dynamic>)
        .toList();
  }

  /// 清除所有緩存數據
  static Future<void> clearCache() async {
    final database = await db;
    if (database == null) return;
    await database.delete('places');
  }

  /// 獲取緩存數據總數
  static Future<int> getCacheCount() async {
    final database = await db;
    if (database == null) return 0;
    final result =
        await database.rawQuery('SELECT COUNT(*) as count FROM places');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
