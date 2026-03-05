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
  List<dynamic> _growthAnalysisArticles = [];
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
// 修改後的函式定義，增加 category 參數
// lib/screens/home_screen.dart 內部的 _showDetailDialog 完整實作

void _showDetailDialog(String title, String content, {String? url, String category = '衛教資訊'}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: '',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (ctx, anim1, anim2) {
      return Center(
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. 使用 ClipPath 達成票券缺口效果
              ClipPath(
                clipper: TicketClipper(),
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  // 限制彈窗最大高度，防止長文章撐破螢幕
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 2. 內容區域：包裹在 SingleChildScrollView 中以支援滑動
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '文章類別：$category',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF4A0E0E),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  color: Color(0xFF4A0E0E),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              
                              // 虛線裝飾 (需對準 TicketClipper 的 vOffset)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 37),
                                child: Row(
                                  children: List.generate(20, (index) => Expanded(
                                    child: Container(
                                      color: Colors.white,
                                      height: 2,
                                      margin: const EdgeInsets.symmetric(horizontal: 2),
                                    ),
                                  )),
                                ),
                              ),
                              
                              // 文章內文
                              Text(
                                content,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF4A0E0E),
                                  height: 1.5,
                                ),
                              ),
                              
                              // 如果有 URL，顯示底部按鈕
                              if (url != null && url.isNotEmpty) ...[
                                const SizedBox(height: 20),
                                const Divider(color: Colors.white, thickness: 2),
                                const SizedBox(height: 10),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    _openLink(url); // 呼叫原本的連結開啟邏輯
                                  },
                                  child: const Text(
                                    '前往外部連結 >>',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Color(0xFF4A0E0E),
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // 3. 圓形關閉按鈕
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Color(0xFF4A0E0E), size: 30),
                ),
              ),
            ],
          ),
        ),
      );
    },
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
                      const SizedBox(height: 10),
                      _buildGrowthTrendSection(), 

                      const SizedBox(height: 24),

                      // 7. 適齡繪本推薦 (圖片 2 樣式)
                      
                      _buildBooksSection(), 

                      const SizedBox(height: 24),

                      // 8. 精選衛教文章 (圖片 2 樣式)
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
  return Container(
    // 加上橘色框框的外層裝飾
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFfff5ea), // 淺米色背景
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: const Color(0xFFFF8C00), // 橘色邊框顏色
        width: 2,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 區塊標題
        const Text(
          '生長趨勢分析',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF4A0E0E),
          ),
        ),
        const SizedBox(height: 16),
        
        // 1. 點擊查看生長曲線的入口卡片
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BmiChartScreen(
                  growthRecords: _growthRecords,
                  babyBirthDate: _babyBirthDate, // 傳入寶寶生日
                ),
              ),
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5), // 淺灰色內容背景
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '點擊查看生長曲線',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4A0E0E),
                  ),
                ),
                Text('>>', style: TextStyle(fontSize: 18, color: Color(0xFF4A0E0E))),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // 2. 猛長期建議卡片
        if (_isGrowthSpurt)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8), // 白色半透明背景
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.trending_up, color: Color(0xFFFF8C00)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '生長衝刺期 (猛長期)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF4A0E0E),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '最近生長曲線變陡，寶寶可能食慾大增或情緒不穩',
                        style: TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _showDetailDialog(
                    '猛長期護理',
                    '猛長期通常持續 2-7 天，寶寶會頻繁討奶，請按需餵養。情緒方面請多給予安撫與抱抱。',
                  ),
                  child: const Text('如何安撫', style: TextStyle(color: Color(0xFFFF8C00))),
                ),
              ],
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
        onTap: () => _showDetailDialog('流感疫情警報', _alertSummary?['message'] ?? '請注意防疫',category: '流感疫情警報'),
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
        onTap: () => _showDetailDialog(title, alert['content'] ?? desc, url: alert['link'],category: '今日環境與警示'),
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
// 2. 適齡繪本 (橫向滑動，符合圖1樣式)
  Widget _buildBooksSection() {
    final books = _apiData?['books'] as List?;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5EA), // 整個區塊的淺橘色背景
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFF8C00), width: 2), // 橘色大外框
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '適齡繪本推薦',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4A0E0E),
            ),
          ),
          const SizedBox(height: 16),
          
          if (books == null || books.isEmpty)
            const Text('目前無相關書籍推薦', style: TextStyle(color: Colors.grey))
          else
            SizedBox(
              height: 190, // 稍微增加高度以容納拉長的方框
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: books.length,
                separatorBuilder: (c, i) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final item = books[index];
                  return GestureDetector(
                    onTap: () => _showDetailDialog(item['title'], item['description'], url: item['source_url'], category: '適齡繪本推薦'),
                    child: Container(
                      width: 120,
                      // 此 Container 即為「長棕色方框」，包含圖片與文字
                      decoration: BoxDecoration(
                        color: const Color(0xFFd8cec6), // 棕色/米色背景
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: const Color(0xFF4f000b), width: 1.5), // 深褐色邊框
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // 貓頭鷹圖片
                          Expanded(
                            child: Image.asset(
                              'image/owl_book.png', // 引用專案插圖
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // 書名 (現在已在邊框內)
                          Text(
                            item['title'] ?? '書籍',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4f000b),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
  // 3. 精選文章 (直向列表)
// 3. 精選文章 (直向列表，符合圖1樣式)
  Widget _buildArticlesSection() {
    final rawArticles = _apiData?['articles'] as List?;
    if (rawArticles == null || rawArticles.isEmpty) {
      return const Text('暫無文章推薦', style: TextStyle(color: Colors.grey));
    }

    // 過濾邏輯保持不變
    final displayArticles = rawArticles.where((item) {
      final tags = List<String>.from(item['tags'] ?? []);
      if (tags.contains('#Event_Fever')) return _latestTemp != null && _latestTemp! > 38.0;
      if (tags.contains('#Event_LowTemp')) return _latestTemp != null && _latestTemp! < 35.0;
      if (tags.contains('#Ctx_FluSeason')) return _alertSummary?['flu_warning'] == true;
      if (tags.contains('#Ctx_Cold')) return _weatherTemp != null && _weatherTemp! < 16.0;
      if (tags.contains('#Ctx_Hot')) return _weatherTemp != null && _weatherTemp! > 30.0;
      return true;
    }).toList();

    if (displayArticles.isEmpty) {
      return const Text('目前狀況良好，無緊急推薦文章', style: TextStyle(color: Colors.grey));
    }

    // 橘色大外框容器
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5EA), // 淺橘色背景
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFF8C00), width: 2), // 深橘色外框
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 內部標題
          const Text(
            '精選衛教文章',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4A0E0E), // 深褐色
            ),
          ),
          const SizedBox(height: 16),

          // 文章列表
          ListView.separated(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayArticles.length,
            separatorBuilder: (c, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = displayArticles[index];
              return GestureDetector(
                onTap: () => _showDetailDialog(item['title'], item['content'], url: item['source_url'], category: '精選衛教文章'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF8C00), // 橘色背景卡片
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item['title'] ?? '文章',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4A0E0E), // 深褐色文字
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Text(
                        '>>',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4A0E0E),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
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
            onPressed: () => _showDetailDialog('猛長期護理', '猛長期內容...', category: '生長趨勢分析'),
            child: const Text('如何安撫'),
          ),
        ],
      ),
    );
  }
}
// 自定義裁剪器：在兩側中間各挖掉一個半圓
class TicketClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    double radius = 12.0; // 挖掉半圓的半徑
    double vOffset = 120.0; // 缺口垂直位置，可根據標題高度調整

    path.lineTo(0, vOffset - radius);
    path.arcToPoint(
      Offset(0, vOffset + radius),
      radius: Radius.circular(radius),
      clockwise: true,
    );
    path.lineTo(0, size.height);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, vOffset + radius);
    path.arcToPoint(
      Offset(size.width, vOffset - radius),
      radius: Radius.circular(radius),
      clockwise: true,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}