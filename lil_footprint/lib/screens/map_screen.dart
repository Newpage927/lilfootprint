import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../local/place_cache_db.dart';
import '../platform_exceptions.dart';

// API defaults (override via PlacesMapView parameters when embedding)
const String defaultApiBase = 'http://35.194.206.11';
const String defaultApiKey = 'Hello';

// Place data model
class PlaceItem {
  final String id;
  final String name;
  final String? address;
  final double lat;
  final double lng;
  final String category;
  final String? city;
  final Map<String, dynamic> properties;

  PlaceItem({
    required this.id,
    required this.name,
    this.address,
    required this.lat,
    required this.lng,
    required this.category,
    this.city,
    required this.properties,
  });

  bool get hasValidLatLng => lat != 0 && lng != 0;

  // 是否為幼兒園類別
  bool get isKindergartenCategory {
    return category.contains('kindergarten') ||
        category.contains('daycare') ||
        category == 'public_kindergarten' ||
        category == 'private_kindergarten' ||
        category == 'quasi_public_kindergarten' ||
        category == 'non_profit_kindergarten';
  }

  // 取得 district（僅幼兒園）
  String? get district =>
      isKindergartenCategory ? properties['district']?.toString() : null;

  // 取得 phone（僅幼兒園）
  String? get phone =>
      isKindergartenCategory ? properties['phone']?.toString() : null;

  // 是否為親子車位類別
  bool get isParentParkingCategory => category == 'parent_parking';

  // 取得車位數量（僅親子車位）
  int? get parkingQuantity {
    if (!isParentParkingCategory) return null;
    final quantity = properties['quantity'];
    if (quantity == null) return null;
    if (quantity is int) return quantity;
    if (quantity is String) return int.tryParse(quantity);
    return null;
  }

  // 是否為廁所類別
  bool get isToiletCategory => category == 'toilet';

  // 取得樓層資訊（僅廁所）
  // 支援多種資料格式：int / String / List
  String? get floors {
    if (!isToiletCategory) return null;
    final f = properties['floors'];
    if (f == null) return null;
    if (f is String) return f;
    if (f is int) return f.toString();
    if (f is List) return f.map((e) => e.toString()).join(', ');
    return f.toString();
  }

  factory PlaceItem.fromJson(Map<String, dynamic> json) {
    return PlaceItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString(),
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      category: json['category']?.toString() ?? '',
      city: json['city']?.toString(),
      properties: json['properties'] as Map<String, dynamic>? ?? {},
    );
  }
}

class PlacesMapView extends StatefulWidget {
  const PlacesMapView({
    super.key,
    this.apiBase = defaultApiBase,
    this.apiKey = defaultApiKey,
    this.showMyLocationButton = true,
    this.showFilterButton = true,
  });

  // Override API settings when embedding.
  final String apiBase;
  final String apiKey;

  final bool showMyLocationButton;
  final bool showFilterButton;

  @override
  State<PlacesMapView> createState() => _PlacesMapViewState();
}

class _PlacesMapViewState extends State<PlacesMapView> {
  final MapController _mapController = MapController();

  // 地圖狀態
  LatLng _center = const LatLng(25.0330, 121.5654); // 台北市預設位置
  double _zoom = 13.0;

  // 資料狀態
  List<PlaceItem> _items = [];
  PlaceItem? _selected;
  bool _loading = false;
  String? _error;

  // 用戶當前位置
  LatLng? _currentUserLocation;

  // Category 篩選（多選）
  final Map<String, bool> _categoryFilters = {
    'park': false,
    'toilet': false,
    'parenting_center': false,
    'public_kindergarten': false,
    'private_kindergarten': false,
    'quasi_public_kindergarten': false,
    'non_profit_kindergarten': false,
    'public_daycare': false,
    'private_daycare': false,
    'riverside_park': false,
    'riverside_playground': false,
    'parent_parking': false,
  };

  // 縣市和地區篩選（僅用於 kindergarten/daycare）
  String? _selectedCity;
  String? _selectedDistrict;

  // 縣市名稱映射（API 格式 → 顯示名稱）
  static const Map<String, String> _cityNameMap = {
    'taipei': '台北',
    'new_taipei': '新北市',
    'taoyuan': '桃園市',
    'taichung': '台中市',
    'tainan': '台南市',
    'kaohsiung': '高雄市',
    'keelung': '基隆市',
    'hsinchu_city': '新竹市',
    'chiayi_city': '嘉義市',
    'hsinchu_county': '新竹縣',
    'miaoli': '苗栗縣',
    'changhua': '彰化縣',
    'nantou': '南投縣',
    'yunlin': '雲林縣',
    'chiayi_county': '嘉義縣',
    'pingtung': '屏東縣',
    'yilan': '宜蘭縣',
    'hualien': '花蓮縣',
    'taitung': '台東縣',
    'penghu': '澎湖縣',
    'kinmen': '金門縣',
    'lienchiang': '連江縣',
  };

  // 從 API 獲取的可用縣市列表（基於當前選中的類別）
  List<String> _availableCities = [];
  bool _loadingCities = false;
  List<String> _cachedCitiesForCategories = []; // 緩存：記錄上次獲取城市時的類別

  // 從 API 獲取的可用區域列表（基於當前選中的類別和縣市）
  List<String> _availableDistricts = [];
  bool _loadingDistricts = false;
  String? _cachedDistrictsForCity; // 緩存：記錄上次獲取區域時的城市
  List<String> _cachedDistrictsForCategories = []; // 緩存：記錄上次獲取區域時的類別

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _mapController.mapEventStream.listen((event) {
      if (event is MapEventMoveEnd || event is MapEventScrollWheelZoom) {
        _fetchForCurrentView();
      }
    });
  }

  // 打開 Google Maps 導航到指定位置
  // 修改後的 _openDirections
  Future<void> _openDirections(PlaceItem item) async {
    final lat = item.lat;
    final lng = item.lng;

    if (lat.isNaN || lng.isNaN) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('座標無效，無法開啟地圖')),
      );
      return;
    }

    // Google Maps（最通用）
    final googleUri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '$lat,$lng',
    });

    try {
      final opened = await launchUrl(
        googleUri,
        mode: LaunchMode.externalApplication,
      );

      if (opened) return;

      final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
      await launchUrl(
        geoUri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('無法開啟地圖：$e')),
      );
    }
  }


  // 取得目前位置
  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _error = '請開啟定位服務';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _error = '定位權限被拒絕';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _error = '定位權限被永久拒絕';
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      final userLocation = LatLng(position.latitude, position.longitude);
      setState(() {
        _center = userLocation;
        _currentUserLocation = userLocation;
        _zoom = 15.0;
      });

      _mapController.move(_center, _zoom);
      _fetchForCurrentView();
    } catch (e) {
      setState(() {
        _error = '取得位置失敗：$e';
      });
    }
  }

  // 取得已選取的 categories
  List<String> _selectedCategories() {
    return _categoryFilters.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
  }

  // 計算當前地圖視窗的 bbox
  String _currentBboxString() {
    final bounds = _mapController.camera.visibleBounds;
    // 格式: minLng,minLat,maxLng,maxLat
    return '${bounds.west},${bounds.south},${bounds.east},${bounds.north}';
  }

  // 多 category API 呼叫
  Future<List<PlaceItem>> _fetchPlacesMulti({
    String? bbox,
    required List<String> categories,
    String? city,
    String? district,
  }) async {
    // 調試：檢查請求參數
    debugPrint('API 請求參數:');
    debugPrint('  categories: $categories');
    debugPrint('  bbox: $bbox');
    debugPrint('  city: $city');
    debugPrint('  district: $district');
    debugPrint(
        '  public_kindergarten 是否在列表中: ${categories.contains('public_kindergarten')}');

    final queryParameters = <String, List<String>>{
      "category": categories, // ⭐ 關鍵：多 category
      if (bbox != null) "bbox": [bbox],
      if (city != null) "city": [city],
      if (district != null) "district": [district],
    };

    // 調試：檢查查詢參數
    debugPrint('查詢參數構建:');
    for (final entry in queryParameters.entries) {
      debugPrint('  ${entry.key}: ${entry.value}');
    }

    final query = queryParameters.entries
        .expand(
          (entry) => entry.value.map(
            (value) =>
                "${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(value)}",
          ),
        )
        .join("&");
    final uri = Uri.parse("${widget.apiBase}/api/places?$query");

    debugPrint('完整 API URL: $uri');
    debugPrint('URL 查詢字符串: ${uri.query}');

    final headers = <String, String>{
      "Accept": "application/json",
    };
    if (widget.apiKey.trim().isNotEmpty) {
      headers["X-API-Key"] = widget.apiKey.trim();
    }

    try {
      final resp = await http.get(uri, headers: headers).timeout(
            const Duration(seconds: 10),
          );

      if (resp.statusCode == 403) {
        throw Exception("403：API Key 驗證失敗");
      }
      if (resp.statusCode != 200) {
        throw Exception("${resp.statusCode}：${resp.body}");
      }

      final decoded = json.decode(utf8.decode(resp.bodyBytes));
      final rawItems = decoded["items"] as List<dynamic>? ?? [];

      // 調試：檢查返回的數據
      debugPrint('API 返回的項目數量: ${rawItems.length}');
      final categoryCounts = <String, int>{};
      for (final item in rawItems) {
        if (item is Map<String, dynamic>) {
          final cat = item['category']?.toString() ?? 'unknown';
          categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
        }
      }
      debugPrint('API 返回的類別統計: $categoryCounts');

      final items = rawItems
          .whereType<Map<String, dynamic>>()
          .map(PlaceItem.fromJson)
          .where((p) => p.hasValidLatLng)
          .toList();

      // 調試：檢查過濾後的數據
      final filteredCategoryCounts = <String, int>{};
      for (final item in items) {
        filteredCategoryCounts[item.category] =
            (filteredCategoryCounts[item.category] ?? 0) + 1;
      }
      debugPrint('過濾後的類別統計: $filteredCategoryCounts');
      debugPrint(
          'public_kindergarten 數量: ${filteredCategoryCounts['public_kindergarten'] ?? 0}');

      return items;
    } catch (e) {
      if (isSocketException(e)) {
        throw Exception("無法連接到 API 伺服器，請確認 Docker 容器是否運行");
      }
      throw Exception("API 請求失敗：$e");
    }
  }

  // 從緩存載入數據（優先顯示）
  Future<void> _loadFromCacheFirst({
    required String bbox,
    required List<String> categories,
  }) async {
    try {
      final parts = bbox.split(',').map(double.parse).toList();
      if (parts.length != 4) return;

      final cached = await PlaceCacheDB.queryPlaces(
        minLng: parts[0],
        minLat: parts[1],
        maxLng: parts[2],
        maxLat: parts[3],
        categories: categories,
      );

      if (cached.isNotEmpty) {
        // 調試：檢查緩存數據
        final cachedCategoryCounts = <String, int>{};
        for (final item in cached) {
          final cat = item['category']?.toString() ?? 'unknown';
          cachedCategoryCounts[cat] = (cachedCategoryCounts[cat] ?? 0) + 1;
        }
        debugPrint('緩存中的類別統計: $cachedCategoryCounts');
        debugPrint(
            '緩存中 public_kindergarten 數量: ${cachedCategoryCounts['public_kindergarten'] ?? 0}');

        setState(() {
          _items = cached
              .map(PlaceItem.fromJson)
              .where((p) => p.hasValidLatLng)
              .toList();

          // 調試：檢查過濾後的緩存數據
          final filteredCachedCounts = <String, int>{};
          for (final item in _items) {
            filteredCachedCounts[item.category] =
                (filteredCachedCounts[item.category] ?? 0) + 1;
          }
          debugPrint('過濾後的緩存類別統計: $filteredCachedCounts');
          debugPrint(
              '過濾後緩存中 public_kindergarten 數量: ${filteredCachedCounts['public_kindergarten'] ?? 0}');

          if (_selected != null && !_items.any((p) => p.id == _selected!.id)) {
            _selected = null;
          }
        });
      }
    } catch (e) {
      // 緩存讀取失敗不影響主流程，靜默處理
      debugPrint('緩存讀取失敗：$e');
    }
  }

  // 檢查是否有選中 kindergarten/daycare 類別
  bool _hasKindergartenOrDaycareCategory() {
    final selected = _selectedCategories();
    return selected
        .any((cat) => cat.contains('kindergarten') || cat.contains('daycare'));
  }

  // 從 API 獲取可用的縣市列表（基於當前選中的類別）
  Future<void> _fetchAvailableCities({bool forceRefresh = false}) async {
    final cats = _selectedCategories();
    if (cats.isEmpty || !_hasKindergartenOrDaycareCategory()) {
      setState(() {
        _availableCities = [];
        _cachedCitiesForCategories = [];
      });
      return;
    }

    // 檢查緩存：如果類別沒有變化且已有數據，不需要重新獲取
    final catsSorted = cats.toList()..sort();
    if (!forceRefresh &&
        _availableCities.isNotEmpty &&
        _cachedCitiesForCategories.length == catsSorted.length &&
        _cachedCitiesForCategories.every((c) => catsSorted.contains(c)) &&
        catsSorted.every((c) => _cachedCitiesForCategories.contains(c))) {
      debugPrint('使用緩存的縣市列表');
      return;
    }

    setState(() {
      _loadingCities = true;
    });

    try {
      // 構建查詢參數
      final queryParameters = <String, List<String>>{
        "category": cats,
      };
      final query = queryParameters.entries
          .expand(
            (entry) => entry.value.map(
              (value) =>
                  "${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(value)}",
            ),
          )
          .join("&");
      final uri = Uri.parse("${widget.apiBase}/api/cities?$query");

      final headers = <String, String>{
        "Accept": "application/json",
      };
      if (widget.apiKey.trim().isNotEmpty) {
        headers["X-API-Key"] = widget.apiKey.trim();
      }

      final resp = await http.get(uri, headers: headers).timeout(
            const Duration(seconds: 10),
          );

      if (resp.statusCode == 403) {
        throw Exception("403：API Key 驗證失敗");
      }
      if (resp.statusCode != 200) {
        throw Exception("${resp.statusCode}：${resp.body}");
      }

      final decoded = json.decode(utf8.decode(resp.bodyBytes));
      final citiesList = decoded["cities"] as List<dynamic>? ?? [];

      // 提取城市代碼列表
      final cityCodes = citiesList
          .whereType<Map<String, dynamic>>()
          .map((city) => city["code"]?.toString())
          .where((code) => code != null && code.isNotEmpty)
          .cast<String>()
          .toList();

      setState(() {
        _availableCities = cityCodes..sort();
        _loadingCities = false;
        _cachedCitiesForCategories = cats.toList()..sort(); // 更新緩存
      });
    } catch (e) {
      debugPrint('獲取縣市列表失敗：$e');
      setState(() {
        _availableCities = [];
        _loadingCities = false;
      });
    }
  }

  // 從 API 獲取可用的區域列表（基於當前選中的類別和縣市）
  Future<void> _fetchAvailableDistricts({bool forceRefresh = false}) async {
    if (_selectedCity == null) {
      setState(() {
        _availableDistricts = [];
        _cachedDistrictsForCity = null;
        _cachedDistrictsForCategories = [];
      });
      return;
    }

    final cats = _selectedCategories();
    if (cats.isEmpty || !_hasKindergartenOrDaycareCategory()) {
      setState(() {
        _availableDistricts = [];
        _cachedDistrictsForCity = null;
        _cachedDistrictsForCategories = [];
      });
      return;
    }

    // 檢查緩存：如果城市和類別都沒有變化且已有數據，不需要重新獲取
    final catsSorted = cats.toList()..sort();
    if (!forceRefresh &&
        _availableDistricts.isNotEmpty &&
        _cachedDistrictsForCity == _selectedCity &&
        _cachedDistrictsForCategories.length == catsSorted.length &&
        _cachedDistrictsForCategories.every((c) => catsSorted.contains(c)) &&
        catsSorted.every((c) => _cachedDistrictsForCategories.contains(c))) {
      debugPrint('使用緩存的區域列表');
      return;
    }

    setState(() {
      _loadingDistricts = true;
    });

    try {
      // 構建查詢參數
      final queryParameters = <String, List<String>>{
        "city": [_selectedCity!],
        "category": cats,
      };
      final query = queryParameters.entries
          .expand(
            (entry) => entry.value.map(
              (value) =>
                  "${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(value)}",
            ),
          )
          .join("&");
      final uri = Uri.parse("${widget.apiBase}/api/districts?$query");

      final headers = <String, String>{
        "Accept": "application/json",
      };
      if (widget.apiKey.trim().isNotEmpty) {
        headers["X-API-Key"] = widget.apiKey.trim();
      }

      final resp = await http.get(uri, headers: headers).timeout(
            const Duration(seconds: 10),
          );

      if (resp.statusCode == 403) {
        throw Exception("403：API Key 驗證失敗");
      }
      if (resp.statusCode != 200) {
        throw Exception("${resp.statusCode}：${resp.body}");
      }

      final decoded = json.decode(utf8.decode(resp.bodyBytes));
      final districtsList = decoded["districts"] as List<dynamic>? ?? [];

      // 提取區域名稱列表
      final districtNames = districtsList
          .whereType<Map<String, dynamic>>()
          .map((district) => district["name"]?.toString())
          .where((name) => name != null && name.isNotEmpty)
          .cast<String>()
          .toList();

      setState(() {
        _availableDistricts = districtNames..sort();
        _loadingDistricts = false;
        _cachedDistrictsForCity = _selectedCity; // 更新緩存
        _cachedDistrictsForCategories = cats.toList()..sort(); // 更新緩存
      });
    } catch (e) {
      debugPrint('獲取區域列表失敗：$e');
      setState(() {
        _availableDistricts = [];
        _loadingDistricts = false;
      });
    }
  }

  // 獲取縣市顯示名稱
  String _getCityDisplayName(String cityCode) {
    return _cityNameMap[cityCode] ?? cityCode;
  }

  // 載入當前視窗的資料（先從緩存，再從 API）
  Future<void> _fetchForCurrentView() async {
    final cats = _selectedCategories();
    if (cats.isEmpty) {
      setState(() {
        _items = [];
        _selected = null;
        _error = null;
      });
      return;
    }

    // 如果有選中 kindergarten/daycare 且選擇了縣市/地區，則不限 bbox
    final bool useBbox = !(_hasKindergartenOrDaycareCategory() &&
        (_selectedCity != null || _selectedDistrict != null));
    final String? bbox = useBbox ? _currentBboxString() : null;

    // 步驟 1: 先從緩存載入（立即顯示，僅當使用 bbox 時）
    if (useBbox) {
      await _loadFromCacheFirst(bbox: bbox!, categories: cats);
    }

    // 步驟 2: 從 API 刷新數據（背景更新）
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 調試：檢查請求前的狀態
      debugPrint('=== 開始載入數據 ===');
      debugPrint('選中的類別: $cats');
      debugPrint(
          '是否包含 public_kindergarten: ${cats.contains('public_kindergarten')}');
      debugPrint('使用 bbox: $useBbox, bbox: $bbox');
      debugPrint('選中的縣市: $_selectedCity');
      debugPrint('選中的地區: $_selectedDistrict');

      final items = await _fetchPlacesMulti(
        bbox: bbox,
        categories: cats,
        city: _selectedCity,
        district: _selectedDistrict,
      );

      debugPrint('=== API 返回完成 ===');
      debugPrint('返回的項目總數: ${items.length}');

      // 步驟 2.5: 如果選擇了 district，在前端進行額外過濾（以防 API 不支持）
      List<PlaceItem> filteredItems = items;
      if (_selectedDistrict != null) {
        debugPrint('=== District 篩選檢查 ===');
        debugPrint('選中的 district: $_selectedDistrict');
        final beforeCount = filteredItems.length;

        // 只保留符合 district 的項目（僅對 kindergarten/daycare 類別）
        filteredItems = items.where((item) {
          if (item.isKindergartenCategory) {
            // 對於 kindergarten/daycare 類別，必須匹配 district
            return item.district == _selectedDistrict;
          } else {
            // 對於其他類別，保留所有項目
            return true;
          }
        }).toList();

        final afterCount = filteredItems.length;
        debugPrint('過濾前項目數: $beforeCount');
        debugPrint('過濾後項目數: $afterCount');

        if (beforeCount != afterCount) {
          debugPrint(
              '✅ 前端過濾生效：移除了 ${beforeCount - afterCount} 個不符合 district 的項目');
        }
      }

      // 步驟 3: 保存到緩存（使用過濾後的數據）
      if (filteredItems.isNotEmpty) {
        final itemsJson = filteredItems.map((item) {
          return {
            'id': item.id,
            'name': item.name,
            'address': item.address,
            'lat': item.lat,
            'lng': item.lng,
            'category': item.category,
            'city': item.city,
            'properties': item.properties,
          };
        }).toList();

        await PlaceCacheDB.upsertPlaces(itemsJson);
      }

      // 步驟 4: 更新 UI（使用過濾後的數據）
      // 調試：檢查最終顯示的數據
      final finalCategoryCounts = <String, int>{};
      for (final item in filteredItems) {
        finalCategoryCounts[item.category] =
            (finalCategoryCounts[item.category] ?? 0) + 1;
      }
      debugPrint('最終顯示的類別統計: $finalCategoryCounts');
      debugPrint(
          '最終 public_kindergarten 數量: ${finalCategoryCounts['public_kindergarten'] ?? 0}');
      debugPrint('選中的類別: $cats');
      debugPrint('最終顯示的項目數: ${filteredItems.length}');

      setState(() {
        _items = filteredItems;
        if (_selected != null && !_items.any((p) => p.id == _selected!.id)) {
          _selected = null;
        }
        // 如果沒有數據，不顯示錯誤（可能是該地區確實沒有該類別）
        if (items.isEmpty &&
            _hasKindergartenOrDaycareCategory() &&
            (_selectedCity != null || _selectedDistrict != null)) {
          _error = null; // 靜默處理，不顯示錯誤
        }
      });
    } catch (e) {
      setState(() {
        // 如果 API 失敗但緩存有數據，不顯示錯誤
        if (_items.isEmpty) {
          // 只有在非縣市/地區篩選時才顯示錯誤
          if (!(_hasKindergartenOrDaycareCategory() &&
              (_selectedCity != null || _selectedDistrict != null))) {
            _error = "載入失敗：$e";
          }
        }
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  // Category 名稱顯示
  String _categoryDisplayName(String category) {
    const names = {
      'park': '公園',
      'toilet': '廁所',
      'parenting_center': '親子館',
      'public_kindergarten': '公立幼兒園',
      'private_kindergarten': '私立幼兒園',
      'quasi_public_kindergarten': '準公共幼兒園',
      'non_profit_kindergarten': '非營利幼兒園',
      'public_daycare': '公立托嬰中心',
      'private_daycare': '私立托嬰中心',
      'riverside_park': '河濱公園',
      'riverside_playground': '河濱公園遊戲區',
      'parent_parking': '親子車位',
    };
    return names[category] ?? category;
  }

  // Marker 顏色（依 category）
  Color _categoryColor(String category) {
    const colors = {
      'park': Colors.green,
      'toilet': Colors.blue,
      'parenting_center': Colors.purple,
      'public_kindergarten': Colors.orange,
      'private_kindergarten': Colors.red,
      'quasi_public_kindergarten': Colors.amber,
      'non_profit_kindergarten': Colors.teal,
      'public_daycare': Colors.pink,
      'private_daycare': Colors.deepPurple,
      'riverside_park': Colors.teal,
      'riverside_playground': Colors.indigo,
      'parent_parking': Colors.pinkAccent,
    };
    return colors[category] ?? Colors.grey;
  }

  // 顯示分類篩選面板
  void _showCategoryFilterPanel() {
    // 如果選中了 kindergarten/daycare，獲取可用縣市（使用緩存，不強制刷新）
    if (_hasKindergartenOrDaycareCategory()) {
      _fetchAvailableCities(forceRefresh: false);
      if (_selectedCity != null) {
        _fetchAvailableDistricts(forceRefresh: false);
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // 拖拽指示器
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // 標題
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '分類篩選（可多選）',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                // 縣市和地區選擇（僅當選中 kindergarten/daycare 時顯示）
                if (_hasKindergartenOrDaycareCategory()) ...[
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '縣市選擇（可選）',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_loadingCities)
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ChoiceChip(
                                label: const Text('全部'),
                                selected: _selectedCity == null,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedCity = null;
                                    _selectedDistrict = null;
                                    _availableDistricts = [];
                                  });
                                  setModalState(() {});
                                  _fetchForCurrentView();
                                },
                              ),
                              ..._availableCities.map((cityCode) {
                                final cityName = _getCityDisplayName(cityCode);
                                return ChoiceChip(
                                  label: Text(cityName),
                                  selected: _selectedCity == cityCode,
                                  onSelected: (selected) async {
                                    setState(() {
                                      _selectedCity =
                                          selected ? cityCode : null;
                                      _selectedDistrict = null; // 重置地區
                                      _availableDistricts = [];
                                      _cachedDistrictsForCity = null;
                                      _cachedDistrictsForCategories = [];
                                    });
                                    setModalState(() {});
                                    if (selected) {
                                      await _fetchAvailableDistricts(
                                          forceRefresh: true);
                                      setModalState(() {});
                                    }
                                    _fetchForCurrentView();
                                  },
                                );
                              }),
                            ],
                          ),
                        if (_selectedCity != null &&
                            _availableDistricts.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Text(
                            '地區選擇（可選）',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_loadingDistricts)
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ChoiceChip(
                                  label: const Text('全部'),
                                  selected: _selectedDistrict == null,
                                  onSelected: (selected) {
                                    setState(() {
                                      _selectedDistrict = null;
                                    });
                                    setModalState(() {});
                                    _fetchForCurrentView();
                                  },
                                ),
                                ..._availableDistricts
                                    .map((district) => ChoiceChip(
                                          label: Text(district),
                                          selected:
                                              _selectedDistrict == district,
                                          onSelected: (selected) {
                                            setState(() {
                                              _selectedDistrict =
                                                  selected ? district : null;
                                            });
                                            setModalState(() {});
                                            _fetchForCurrentView();
                                          },
                                        )),
                              ],
                            ),
                        ],
                      ],
                    ),
                  ),
                  const Divider(),
                ],
                // Category 選單
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: _categoryFilters.entries.map((entry) {
                        return FilterChip(
                          label: Text(_categoryDisplayName(entry.key)),
                          selected: entry.value,
                          onSelected: (selected) {
                            setState(() {
                              _categoryFilters[entry.key] = selected;
                            });
                            setModalState(() {});
                            // 如果選中了 kindergarten/daycare，更新縣市列表（強制刷新）
                            if (selected &&
                                (entry.key.contains('kindergarten') ||
                                    entry.key.contains('daycare'))) {
                              _fetchAvailableCities(forceRefresh: true)
                                  .then((_) {
                                setModalState(() {});
                              });
                            } else if (!selected) {
                              // 如果取消選擇，清除緩存
                              setState(() {
                                _cachedCitiesForCategories = [];
                                _cachedDistrictsForCity = null;
                                _cachedDistrictsForCategories = [];
                              });
                            }
                            _fetchForCurrentView();
                          },
                          selectedColor:
                              _categoryColor(entry.key).withOpacity(0.3),
                          checkmarkColor: _categoryColor(entry.key),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 地圖區域
        Positioned.fill(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _center,
                  initialZoom: _zoom,
                  onTap: (tapPosition, point) {
                    setState(() {
                      _selected = null;
                    });
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.places_map_app',
                  ),
                  MarkerLayer(
                    markers: [
                      // 用戶當前位置標記
                      if (_currentUserLocation != null)
                        Marker(
                          point: _currentUserLocation!,
                          width: 40,
                          height: 40,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.3),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.my_location,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      // 地點標記
                      ..._items.map((item) {
                        return Marker(
                          point: LatLng(item.lat, item.lng),
                          width: 30,
                          height: 30,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selected = item;
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: _categoryColor(item.category),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                  if (_selected != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(_selected!.lat, _selected!.lng),
                          width: 40,
                          height: 40,
                          child: Container(
                            decoration: BoxDecoration(
                              color: _categoryColor(_selected!.category),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.yellow,
                                width: 3,
                              ),
                            ),
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),

              // 載入指示器
              if (_loading)
                const Center(
                  child: CircularProgressIndicator(),
                ),

              // 錯誤訊息
              if (_error != null && !_loading)
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () {
                            setState(() {
                              _error = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        if (widget.showMyLocationButton)
          Positioned(
            right: 16,
            top: 16,
            child: SafeArea(
              top: true,
              bottom: false,
              child: FloatingActionButton.small(
                onPressed: _getCurrentLocation,
                tooltip: '取得目前位置',
                child: const Icon(Icons.my_location),
              ),
            ),
          ),

        if (widget.showFilterButton)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              onPressed: _showCategoryFilterPanel,
              tooltip: '分類篩選',
              child: const Icon(Icons.filter_list),
            ),
          ),

        if (_selected != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _categoryColor(_selected!.category),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _categoryDisplayName(_selected!.category),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selected!.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // 導航按鈕（右側）
                        IconButton(
                          icon: const Icon(Icons.directions, size: 22),
                          tooltip: '導航到此處',
                          onPressed: () => _openDirections(_selected!),
                        ),
                      ],
                    ),
                    if (_selected!.address != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 16),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(_selected!.address!),
                          ),
                        ],
                      ),
                    ],
                    // 僅幼兒園類別顯示 district 和 phone
                    if (_selected!.isKindergartenCategory) ...[
                      if (_selected!.district != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.map, size: 16),
                            const SizedBox(width: 4),
                            Text('區域：${_selected!.district}'),
                          ],
                        ),
                      ],
                      if (_selected!.phone != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.phone, size: 16),
                            const SizedBox(width: 4),
                            Text('電話：${_selected!.phone}'),
                          ],
                        ),
                      ],
                    ],
                    // 僅親子車位類別顯示車位數量
                    if (_selected!.isParentParkingCategory) ...[
                      if (_selected!.parkingQuantity != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.local_parking, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '車位數量：${_selected!.parkingQuantity} 個',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],

                    // 僅廁所類別顯示樓層資訊
                    if (_selected!.isToiletCategory) ...[
                      if (_selected!.floors != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.layers, size: 16),
                            const SizedBox(width: 4),
                            Text('樓層：${_selected!.floors}'),
                          ],
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
