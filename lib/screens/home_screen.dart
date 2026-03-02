import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../service/api_service.dart';
import '../service/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart'; // 新增
import 'growth_chart_detail_screen.dart'; // 引入新檔案

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // --- 狀態變數 ---
  DateTime _babyBirthDate = DateTime.now().subtract(const Duration(days: 165)); // 預設值 (如果讀取失敗會用這個)
  
  bool _isLoading = false;
  Map<String, dynamic>? _apiData; 
  double? _latestTemp;
  double? _weatherTemp;
  List<dynamic> _alerts = [];
  Map<String, dynamic>? _alertSummary;

  // 模擬原本的環境數據 (保留舊版型用)
  final bool _isGrowthSpurt = true; 
  List<Map<String, dynamic>> _growthRecords = [];
  // 計算月齡
  double get _currentAgeMonths {
    final now = DateTime.now();
    final difference = now.difference(_babyBirthDate).inDays;
    return double.parse((difference / 30.0).toStringAsFixed(1));
  }
  // 把它加在 _currentAgeMonths 下面
  String get _formattedAge {
    final now = DateTime.now();
    final difference = now.difference(_babyBirthDate).inDays;
    
    // 如果小於 1 個月，顯示天數
    if (difference < 30) {
      return '$difference 天大';
    } 
    // 如果小於 1 歲，顯示月齡
    else if (difference < 365) {
      final months = (difference / 30).floor();
      return '$months 個月大';
    } 
    // 如果大於 1 歲，顯示 歲 + 月
    else {
      final years = (difference / 365).floor();
      final months = ((difference % 365) / 30).floor();
      if (months == 0) {
         return '$years 歲';
      }
      return '$years 歲 $months 個月';
    }
  }
  @override
  void initState() {
    super.initState();
    _loadData(); // 統一包成一個函式比較整齊
  }
  // 統一讀取資料 (生日 + 體溫 + API)
  Future<void> _loadData() async {
    // 1. 讀取生日 (原本的邏輯)
    final prefs = await SharedPreferences.getInstance();
    final String? savedDate = prefs.getString('baby_birth_date');
    if (savedDate != null) {
      setState(() { _babyBirthDate = DateTime.parse(savedDate); });
    }

    // 2. 🔥 讀取最新體溫 (新增的邏輯)
    final temp = await DatabaseHelper.instance.getLatestTemperature();

    // 3. 讀取生長紀錄 (身高體重)
    final allRecords = await DatabaseHelper.instance.readAllRecords();
    setState(() {
      _latestTemp = temp;
      _growthRecords = allRecords.where((r) => r['type'] == 'growth_body').toList();
      // 依時間排序：舊 -> 新
      _growthRecords.sort((a, b) => a['time'].compareTo(b['time']));
    });
    setState(() {
      _latestTemp = temp; 
    });
    // Debug 檢查用
    print("目前最新體溫: $_latestTemp");
    // 初始化天氣
    _initWeather();

    setState(() {
      _latestTemp = temp;
    });
    // 3. 呼叫 API
    _fetchData();
  }
  Future<void> _initWeather() async {
    try {
      // 檢查權限 (簡單版)
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      // 取得目前位置
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low // 不需要太精準，省電
      );

      // 呼叫剛剛寫好的 API
      final wTemp = await ApiService.fetchLocalTemperature(position.latitude, position.longitude);
      
      if (mounted && wTemp != null) {
        setState(() {
          _weatherTemp = wTemp;
        });
        print("目前所在地氣溫: $_weatherTemp °C"); // Debug 用
      }
    } catch (e) {
      print("定位或天氣錯誤: $e");
    }
  }
  Future<void> _saveBirthDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('baby_birth_date', date.toIso8601String());
  }
  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final double ageInYears = _currentAgeMonths / 12.0;

      final results = await Future.wait([
        ApiService.fetchRecommendations(ageInYears), 
        ApiService.fetchAlerts(), 
      ]);

      if (mounted) {
        setState(() {
          _apiData = results[0];
          
          // 解析新的 Alerts 結構
          final alertResponse = results[1];
          _alertSummary = alertResponse['status_summary']; // 存取 summary
          _alerts = (alertResponse['data'] as List<dynamic>?) ?? []; // 存取 data
          
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          print("API Error: $e");
        });
      }
    }
  }

  Future<void> _selectBirthDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _babyBirthDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: '選擇寶寶生日',
    );
    if (picked != null && picked != _babyBirthDate) {
      setState(() {
        _babyBirthDate = picked;
      });
      
      // 🔥 4. 使用者選完後，立刻存檔
      _saveBirthDate(picked);
      
      _fetchData(); 
    }
  }
  Future<void> _openLink(String urlString) async {
    if (urlString.isEmpty) return;

    final Uri url = Uri.parse(urlString);
    
    // 嘗試開啟 (mode: LaunchMode.externalApplication 代表用手機的瀏覽器開啟，而不是在 App 內開)
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      // 如果開啟失敗 (例如網址錯誤)，顯示錯誤提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('無法開啟連結: $urlString')),
        );
      }
    }
  }
  // --- 新增：顯示詳情的彈窗 ---
  void _showDetailDialog(String title, String content, {String? url}) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min, // 讓視窗根據內容收縮
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(content, style: const TextStyle(height: 1.5, fontSize: 16)),
            if (url != null && url.isNotEmpty) ...[
              const Divider(height: 32),
              const Text('查看更多', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () {
                  Navigator.of(ctx).pop(); // 先關閉彈窗
                  _openLink(url);          // 再開啟連結
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.language, size: 18, color: Colors.blue),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '前往外部連結',
                          style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Icon(Icons.open_in_new, size: 16, color: Colors.blue),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('關閉'),
        ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // 讓背景圖透過來
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderSection(),
                  
                  Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      
                      // 5. 實作圖片 1 下方的「今日環境與警示」卡片
                      _buildTimeSensitiveSection(),
                      
                      const SizedBox(height: 24),

                      // 6. 生長趨勢分析 (圖片 2 樣式)
                      _buildSectionTitle('生長趨勢分析', Icons.ssid_chart),
                      const SizedBox(height: 10),
                      _buildGrowthTrendSection(), 

                      const SizedBox(height: 24),

                      // 7. 適齡繪本推薦 (圖片 2 樣式)
                      _buildSectionTitle('適齡繪本推薦', Icons.menu_book_rounded),
                      const SizedBox(height: 10),
                      _buildBooksSection(), 

                      const SizedBox(height: 24),

                      // 8. 精選衛教文章 (圖片 2 樣式)
                      _buildSectionTitle('精選衛教文章', Icons.article_outlined),
                      const SizedBox(height: 10),
                      _buildArticlesSection(),
                      
                      const SizedBox(height: 40), // 留白避免被導覽列遮住
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }
  Widget _buildHeaderSection() {
  return Stack(
    alignment: Alignment.topCenter,
    children: [
      // 1. 頂部橘色圓弧背景
      Container(
        height: 200,
        decoration: const BoxDecoration(
          color: Color(0xFFFF8C00), // 圖片中的主橘色
          borderRadius: BorderRadius.vertical(
            bottom: Radius.elliptical(250, 125), // 達成下凹的圓弧效果
          ),
        ),
      ),
      
      // 2. 頭像與月齡資訊內容
      Column(
        children: [
          const SizedBox(height: 100), // 往下偏移讓頭像橫跨背景邊界
          
          // 圓形頭像區塊
          Container(
            padding: const EdgeInsets.all(8), // 白色外圈厚度
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 10),
              ],
            ),
            child: const CircleAvatar(
              radius: 65,
              backgroundColor: Color(0xFFFDEFD5), // 頭像背景淡色
              // 請確保 assets 中有此圖片並在 pubspec.yaml 註冊
              backgroundImage: AssetImage('image/baby_owl.png'), 
            ),
          ),
          
          const SizedBox(height: 20),
          
          // 3. 橘色月齡標籤按鈕
          GestureDetector(
            onTap: () => _selectBirthDate(), // 觸發原本的日期選擇功能
            child: Stack(
              alignment: Alignment.topCenter,
              clipBehavior: Clip.none,
              children: [
                // 主要橘色長橢圓標籤
                Container(
                  margin: const EdgeInsets.only(top: 15), // 為上方蛋糕圖示留空間
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF8C00),
                    borderRadius: BorderRadius.circular(30), 
                    border: Border.all(color: const Color(0xFFD3760E), width: 2),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '寶寶 $_formattedAge', // 顯示動態計算的月齡
                        style: const TextStyle(
                          color: Color(0xFF4F000B), // 深褐色文字
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.edit, color: Color(0xFF4F000B), size: 18),
                    ],
                  ),
                ),
                // 上方的蛋糕圖示按鈕
                Positioned(
                  top: -5,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF98C12),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFD3760E), width: 1.5),
                    ),
                    child: const Icon(Icons.cake, color: Color(0xFF4F000B), size: 24),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ],
  );
}
  // --- UI 元件區塊 ---
// lib/screens/home_screen.dart 內部的修改

  Widget _buildGrowthTrendSection() {
    return Column(
      children: [
        // 樣式參考圖片 1：點擊查看生長曲線的入口卡片
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GrowthChartDetailScreen(
                  babyBirthDate: _babyBirthDate, // 將首頁的生日變數傳遞給新頁面
                ),
              ),
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5), // 淺灰色背景
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '點擊查看生長曲線',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4A0E0E)),
                ),
                Text('>>', style: TextStyle(fontSize: 18, color: Color(0xFF4A0E0E))),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 原有的猛長期建議卡片保留
        _buildTrendRecommendations(),
      ],
    );
  }
  
  
  Widget _buildSectionTitle(String title, IconData icon) {
  return Container(
    margin: const EdgeInsets.symmetric(vertical: 8),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: Color(0xfffff5ea).withOpacity(0.9), // 淺色背景
      borderRadius: BorderRadius.circular(20), // 圓潤邊角
      border: Border.all(
        color: const Color(0xFFFF8C00), // 淺橘色邊框
        width: 1.5,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min, // 讓容器寬度隨文字長度縮放
      children: [
        Icon(icon, size: 20, color: const Color(0xFFFF8C00)), // 橘色圖示
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF4A0E0E), // 深褐色文字
          ),
        ),
      ],
    ),
  );
}

  // 1. 即時快訊 (保留舊版邏輯)
  // 1. 即時快訊區塊 (整合：流感警示 + 即時氣溫 + API 警示)
  Widget _buildTimeSensitiveSection() {
    final List<Widget> cards = [];

    // --- (1) 氣溫卡片 (維持原本文字排版，僅換橘色背景) ---
    if (_weatherTemp != null) {
      cards.add(_buildOrangeInfoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.thermostat, size: 16, color: Color(0xFF4A0E0E)),
                const SizedBox(width: 6),
                const Text('目前位置', style: TextStyle(fontSize: 12, color: Color(0xFF4A0E0E))),
              ],
            ),
            const Spacer(),
            Text(
              '${_weatherTemp!.toStringAsFixed(1)}°C',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 32, color: Color(0xFF4A0E0E)),
            ),
            const SizedBox(height: 4),
            Text(
              _weatherTemp! < 16 ? '天氣寒冷，注意保暖' : (_weatherTemp! > 30 ? '氣溫炎熱，多喝水' : '氣溫舒適，適合外出'),
              style: const TextStyle(fontSize: 12, color: Color(0xFF4A0E0E)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ));
    }

    // --- (2) 流感警示卡片 ---
    if (_alertSummary?['flu_warning'] == true) {
      cards.add(_buildOrangeInfoCard(
        onTap: () => _showDetailDialog('流感疫情警報', _alertSummary?['message'] ?? '請注意防疫'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.sick, size: 16, color: Color(0xFF4A0E0E)),
                SizedBox(width: 8),
                Text('疾管署警示', style: TextStyle(fontSize: 12, color: Color(0xFF4A0E0E))),
              ],
            ),
            const SizedBox(height: 12),
            const Text('流感疫情高峰警報', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF4A0E0E))),
            const SizedBox(height: 4),
            Text(
              _alertSummary?['message'] ?? '請注意防疫',
              style: const TextStyle(fontSize: 12, color: Color(0xFF4A0E0E)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ));
    }

    // --- (3) 一般 API 警示卡片 (維持原本左右排版邏輯) ---
    for (var alert in _alerts) {
      final String source = alert['source'] ?? '通知';
      final String title = alert['title'] ?? '無標題';
      final String desc = alert['content_snippet'] ?? '';

      cards.add(_buildOrangeInfoCard(
        onTap: () => _showDetailDialog(title, alert['content'] ?? desc, url: alert['link']),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info, size: 14, color: Color(0xFF4A0E0E)),
                const SizedBox(width: 8),
                Text(source, style: const TextStyle(fontSize: 12, color: Color(0xFF4A0E0E))),
              ],
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF4A0E0E)), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Expanded(
              child: Text(desc, style: const TextStyle(fontSize: 12, color: Color(0xFF4A0E0E)), maxLines: 2, overflow: TextOverflow.ellipsis)
            ),
          ],
        ),
      ));
    }

    // 組合外層框架
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFfff5ea),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFF8C00), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '今日環境與警示',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF4A0E0E)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150, // 增加高度以容納原本的文字排版
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: cards.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) => SizedBox(
                width: 180, // 維持原本卡片寬度
                child: cards[index],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 輔助元件：橘色圓角卡片
  Widget _buildOrangeInfoCard({required Widget child, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF98C12), // 橘色背景
          borderRadius: BorderRadius.circular(20),
        ),
        child: child,
      ),
    );
  }

  // --- 子元件：流感卡片 ---
  Widget _buildFluCard() {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1), // 淡橘黃
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                child: const Icon(Icons.sick, size: 14, color: Colors.white),
              ),
              const SizedBox(width: 8),
              const Text('疾管署警示', style: TextStyle(fontSize: 12, color: Colors.orange)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(4)),
                child: const Text('極重要', style: TextStyle(fontSize: 10, color: Colors.deepOrange)),
              )
            ],
          ),
          const SizedBox(height: 12),
          const Text('流感疫情高峰警報', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              _alertSummary?['message'] ?? '請注意防疫',
              style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // --- 子元件：氣溫卡片 (新增) ---
  Widget _buildWeatherCard(double temp) {
    // 根據溫度決定顏色與文字
    String statusText;
    Color colorTheme;
    Color bgColor;

    if (temp < 16) {
      statusText = '天氣寒冷，注意保暖';
      colorTheme = Colors.blue;
      bgColor = Colors.blue.shade50;
    } else if (temp > 30) {
      statusText = '氣溫炎熱，多喝水';
      colorTheme = Colors.red;
      bgColor = Colors.red.shade50;
    } else {
      statusText = '氣溫舒適，適合外出';
      colorTheme = Colors.green;
      bgColor = Colors.green.shade50;
    }

    return Container(
      width: 220, // 稍微窄一點
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorTheme.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.thermostat, size: 16, color: colorTheme),
              const SizedBox(width: 6),
              Text('目前位置', style: TextStyle(fontSize: 12, color: colorTheme)),
            ],
          ),
          const Spacer(),
          Text(
            '${temp.toStringAsFixed(1)}°C',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 32, color: colorTheme),
          ),
          const SizedBox(height: 4),
          Text(
            statusText,
            style: TextStyle(fontSize: 12, color: colorTheme.withOpacity(0.8)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // --- 子元件：一般 Alert 卡片 (原本的邏輯) ---
  Widget _buildNormalAlertCard(dynamic alert) {
    final String title = alert['title'] ?? '無標題';
    final String source = alert['source'] ?? '通知';
    final String desc = alert['content_snippet'] ?? '';
    final String link = alert['link'] ?? '';
    final List<dynamic> tags = alert['tags'] ?? [];

    bool isHighRisk = false;
    String tagLabel = '';

    if (tags.toString().contains('ProductRecall') || tags.toString().contains('HeavyMetal')) {
      isHighRisk = true;
      tagLabel = '食安警示';
    }

    IconData icon;
    if (source.contains('CDC')) {
      icon = Icons.medical_services;
    } else if (source.contains('FDA')) {
      icon = Icons.restaurant_menu;
    } else {
      icon = Icons.info;
    }

    return GestureDetector(
      onTap: () => _openLink(link),
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isHighRisk ? const Color(0xFFFFF0F0) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isHighRisk ? Colors.red.shade200 : Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: isHighRisk ? Colors.red : Colors.blue,
                      shape: BoxShape.circle
                  ),
                  child: Icon(icon, size: 14, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Text(source, style: const TextStyle(fontSize: 12, color: AppTheme.subTextColor)),
                const Spacer(),
                if (tagLabel.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: isHighRisk ? Colors.red.shade100 : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(4)
                    ),
                    child: Text(tagLabel, style: TextStyle(fontSize: 10, color: isHighRisk ? Colors.red : Colors.blue)),
                  )
              ],
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Expanded(
                child: Text(desc, style: const TextStyle(fontSize: 12, color: Colors.black54), maxLines: 2, overflow: TextOverflow.ellipsis)
            ),
          ],
        ),
      ),
    );
  }

  // 2. 適齡繪本 (新功能 - 橫向)
  Widget _buildBooksSection() {
    final books = _apiData?['books'] as List?;
    if (books == null || books.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: const Text('目前無相關書籍推薦', style: TextStyle(color: Colors.grey)),
      );
    }

    return SizedBox(
      height: 220, // 設定高度
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: books.length,
        separatorBuilder: (c, i) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = books[index];
          return GestureDetector(
            onTap: () => _showDetailDialog(
              item['title'] ?? '', 
              item['content'] ?? item['description'] ?? '', 
              url: item['source_url'] // 傳入 URL
            ),
            child: Container(
              width: 140,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(child: Icon(Icons.menu_book, size: 40, color: Colors.amber)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(item['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(4)),
                    child: Text('推薦書籍', style: TextStyle(fontSize: 10, color: Colors.amber.shade800)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // 3. 精選文章 (直向列表)
  Widget _buildArticlesSection() {
final rawArticles = _apiData?['articles'] as List?;
    if (rawArticles == null || rawArticles.isEmpty) {
      return const Text('暫無文章推薦', style: TextStyle(color: Colors.grey));
    }

    // 🔥 核心過濾邏輯
    final displayArticles = rawArticles.where((item) {
      final tags = List<String>.from(item['tags'] ?? []);
      
      // 狀況 A: 這是一篇發燒文章 (#Event_Fever)
      if (tags.contains('#Event_Fever')) {
        // 只有當體溫 > 38.0 時才顯示，否則隱藏
        return _latestTemp != null && _latestTemp! > 38.0;
      }

      // 狀況 B: 這是一篇低體溫文章 (#Event_LowTemp)
      if (tags.contains('#Event_LowTemp')) {
        // 只有當體溫 < 35.0 時才顯示，否則隱藏
        return _latestTemp != null && _latestTemp! < 35.0;
      }
      if (tags.contains('#Ctx_FluSeason')) {
        // 只有當 API 說現在是流感高峰期 (flu_warning == true) 才顯示
        return _alertSummary?['flu_warning'] == true;
      }
      if (tags.contains('#Ctx_Cold')) {
        // 如果抓不到氣溫(例如沒開定位)，預設不顯示，避免誤判
        return _weatherTemp != null && _weatherTemp! < 16.0;
      }
      if (tags.contains('#Ctx_Hot')) {
        return _weatherTemp != null && _weatherTemp! > 30.0;
      }
      // 狀況 C: 其他普通文章 (沒有這兩個標籤的)
      // 總是顯示 (或者你要加入其他邏輯)
      return true;
    }).toList();

    // 如果過濾完沒剩下文章
    if (displayArticles.isEmpty) {
       return const Text('目前狀況良好，無緊急推薦文章', style: TextStyle(color: Colors.grey));
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: displayArticles.length,
      separatorBuilder: (c, i) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = displayArticles[index];
        final title = item['title'] ?? '無標題';
        final content = item['content'] ?? '無內容';
        final tags = item['tags'] != null ? List<String>.from(item['tags']) : [];

        // 下面這段維持原本的 UI 渲染邏輯
        Color bgColor = Colors.blue.shade50;
        IconData icon = Icons.article;
        
        // 為了讓緊急狀況更明顯，我們可以加強顏色
        if (tags.toString().contains('Fever')) {
          bgColor = Colors.red.shade100; // 發燒底色深一點
          icon = Icons.local_fire_department; // 換成火的圖示
        } else if (tags.toString().contains('LowTemp')) {
          bgColor = Colors.cyan.shade100;
          icon = Icons.ac_unit; // 雪花圖示
        } else if (tags.toString().contains('FluSeason')) {
          bgColor = Colors.orange.shade100;
          icon = Icons.masks; // 或是 Icons.medical_services
        }

        return GestureDetector(
          onTap: () => _showDetailDialog(
            item['title'] ?? '', 
            item['content'] ?? item['description'] ?? '', 
            url: item['source_url'] // 傳入 URL
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: bgColor == Colors.red.shade100 ? Colors.red : Colors.grey.shade100), // 發燒加紅框
              boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 5, offset: const Offset(0, 2))],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: Colors.black87, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (tags.isNotEmpty)
                        Text(tags.first, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)), 
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(content, style: const TextStyle(fontSize: 13, color: Colors.black54), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                 const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        );
      },
    );
  }

  // 4. 生長建議 (保留舊版邏輯)
  Widget _buildTrendRecommendations() {
    if (!_isGrowthSpurt) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.shade100),
      ),
      child: Row(
        children: [
          const Icon(Icons.trending_up, color: Colors.purple),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('生長衝刺期 (猛長期)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.purple)),
                SizedBox(height: 4),
                Text('最近生長曲線變陡，寶寶可能食慾大增或情緒不穩', style: TextStyle(fontSize: 13, color: Colors.purple)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _showDetailDialog('猛長期護理', '猛長期通常持續 2-7 天，寶寶會頻繁討奶，請按需餵養。情緒方面請多給予安撫與抱抱。'),
            child: const Text('如何安撫'),
          ),
        ],
      ),
    );
  }
}