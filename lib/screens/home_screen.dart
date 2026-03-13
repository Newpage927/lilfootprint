import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../service/api_service.dart';
import '../service/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'growth_chart_detail_screen.dart';
import '../service/growth_data_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // --- 狀態變數 ---
  DateTime _babyBirthDate = DateTime.now().subtract(const Duration(days: 165));
  
  bool _isLoading = false;
  Map<String, dynamic>? _apiData; 
  double? _latestTemp;
  double? _weatherTemp;
  List<dynamic> _alerts = [];
  List<dynamic> _growthAnalysisArticles = [];
  Map<String, dynamic>? _alertSummary;
  String _growthTrend = "normal";
  List<Map<String, dynamic>> _growthRecords = [];

  final bool _isGrowthSpurt = true;
  // 計算月齡
  double get _currentAgeMonths {
    final now = DateTime.now();
    final difference = now.difference(_babyBirthDate).inDays;
    return double.parse((difference / 30.0).toStringAsFixed(1));
  }
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
    _loadData();
  }
  // 統一讀取資料 (生日 + 體溫 + API)
  Future<void> _loadData() async {
    // 1. 讀取生日 (原本的邏輯)
    final prefs = await SharedPreferences.getInstance();
    final String? savedDate = prefs.getString('baby_birth_date');
    if (savedDate != null) {
      setState(() { _babyBirthDate = DateTime.parse(savedDate); });
    }

    // 2. 讀取最新體溫 (新增的邏輯)
    final temp = await DatabaseHelper.instance.getLatestTemperature();

    // 3. 讀取生長紀錄 (身高體重)
    final allRecords = await DatabaseHelper.instance.readAllRecords();
    if (mounted) {
      setState(() {
        _latestTemp = temp;
        _growthRecords = allRecords.where((r) => r['type'] == 'growth_body').toList();
        _growthRecords.sort((a, b) => a['time'].compareTo(b['time']));
      });
      // Debug 檢查用
      print("目前最新體溫: $_latestTemp");
      // 初始化天氣
      _initWeather();

      setState(() {
        _latestTemp = temp;
      });
      await _fetchData();
    }
  }
  Future<void> _initWeather() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      // 取得目前位置
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low
      );

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
  setState(() => _isLoading = true);

  try {
    final double ageInYears = _currentAgeMonths / 12.0;

    String currentTrend = "normal"; // 預設正常
    
    if (_growthRecords.isNotEmpty) {
      // 取得最新一筆紀錄
      final latest = _growthRecords.last;
      final valueStr = latest['value'] ?? "";
      
      // 解析體重數值 (kg)
      final RegExp weightExp = RegExp(r'體重:([\d.]+)kg');
      final match = weightExp.firstMatch(valueStr);
      
      if (match != null) {
        double currentWeight = double.tryParse(match.group(1)!) ?? 0;
        
        final ref = GrowthDataService.boyGrowthReference.firstWhere(
          (r) => r['age'] >= ageInYears, 
          orElse: () => GrowthDataService.boyGrowthReference.last
        );

        if (currentWeight < ref['p3_w']) {
          currentTrend = "stunt"; // 生長偏緩
        } else if (currentWeight > ref['p97_w']) {
          currentTrend = "over";  // 生長超標
        } else if (_isGrowthSpurt) {
          currentTrend = "spurt"; // 猛長期
        }
      }
    }

    final results = await Future.wait([
      ApiService.fetchRecommendations(ageInYears), 
      ApiService.fetchAlerts(), 
      ApiService.fetchGrowthAnalysis(currentTrend),
    ]);

    if (mounted) {
      setState(() {
        _apiData = results[0] as Map<String, dynamic>?;
        
        final alertResponse = results[1] as Map<String, dynamic>?;
        if (alertResponse != null) {
          _alertSummary = alertResponse['status_summary'] as Map<String, dynamic>?;
          _alerts = (alertResponse['data'] as List<dynamic>?) ?? [];
        }

        _growthAnalysisArticles = (results[2] as List<dynamic>?) ?? [];
        _growthTrend = currentTrend;
        _isLoading = false;
      });
    }
  } catch (e) {
    if (mounted) {
      setState(() => _isLoading = false);
      print("讀值或 API 錯誤: $e");
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
      
      _saveBirthDate(picked);
      
      _fetchData(); 
    }
  }
  Future<void> _openLink(String urlString) async {
    if (urlString.isEmpty) return;

    final Uri url = Uri.parse(urlString);
    
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('無法開啟連結: $urlString')),
        );
      }
    }
  }

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
              ClipPath(
                clipper: TicketClipper(),
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.85,
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
                              
                              Text(
                                content,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF4A0E0E),
                                  height: 1.5,
                                ),
                              ),
                              
                              if (url != null && url.isNotEmpty) ...[
                                const SizedBox(height: 20),
                                const Divider(color: Colors.white, thickness: 2),
                                const SizedBox(height: 10),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    _openLink(url);
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
      backgroundColor: Colors.transparent,
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
                      
                      _buildTimeSensitiveSection(),
                      
                      const SizedBox(height: 24),

                      const SizedBox(height: 10),
                      _buildGrowthTrendSection(), 

                      const SizedBox(height: 24),
                      
                      _buildBooksSection(), 

                      const SizedBox(height: 24),

                      const SizedBox(height: 10),
                      _buildArticlesSection(),
                      
                      const SizedBox(height: 40),
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
      Container(
        height: 200,
        decoration: const BoxDecoration(
          color: Color(0xFFFF8C00),
          borderRadius: BorderRadius.vertical(
            bottom: Radius.elliptical(250, 125),
          ),
        ),
      ),
      
      //  頭像與月齡資訊內容
      Column(
        children: [
          const SizedBox(height: 100),
          
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
              backgroundImage: AssetImage('image/baby_owl.png'), 
            ),
          ),
          
          const SizedBox(height: 20),
          
          // 橘色月齡標籤按鈕
          GestureDetector(
            onTap: () => _selectBirthDate(), // 觸發原本的日期選擇功能
            child: Stack(
              alignment: Alignment.topCenter,
              clipBehavior: Clip.none,
              children: [
                // 主要橘色長橢圓標籤
                Container(
                  margin: const EdgeInsets.only(top: 15),
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

Widget _buildGrowthTrendSection() {
  // 根據狀態決定主題顏色
  Color themeColor = const Color(0xFFFF8C00); // 預設橘色
  String trendTitle = "成長進度良好";

  if (_growthTrend == "stunt") {
    themeColor = Colors.redAccent;
    trendTitle = "生長偏緩警示";
  } else if (_growthTrend == "over") {
    themeColor = Colors.deepOrange;
    trendTitle = "生長超標警示";
  } else if (_growthTrend == "spurt") {
    themeColor = Colors.purple;
    trendTitle = "生長衝刺期";
  }

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF5EA),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: themeColor, width: 2),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '生長趨勢分析',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF4A0E0E)),
        ),
        const SizedBox(height: 16),

        // 曲線圖入口
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (context) => BmiChartScreen(
              growthRecords: _growthRecords,
              babyBirthDate: _babyBirthDate,
            ),
          )),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('查看生長曲線圖', style: TextStyle(fontWeight: FontWeight.bold, color: themeColor)),
                Icon(Icons.chevron_right, color: themeColor),
              ],
            ),
          ),
        ),

        // 串接 API 文章列表 (如果不是 normal 且有文章)
        if (_growthTrend != "normal" && _growthAnalysisArticles.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          
          // 遍歷 API 抓回來的文章清單
          ..._growthAnalysisArticles.map((article) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: GestureDetector(
                onTap: () => _showDetailDialog(
                  article['title'] ,
                  article['content'],
                  url: article['source_url'],
                  category: '生長建議',
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  decoration: BoxDecoration(
                    color: themeColor, // 使用動態變化的主題色 (紅/橘/紫)
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lightbulb_outline, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          article['title'] ?? '點擊查看建議',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Text(' >>', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ],
      ],
    ),
  );
}
  
  // 即時快訊區塊 (整合：流感警示 + 即時氣溫 + API 警示)
  Widget _buildTimeSensitiveSection() {
    final List<Widget> cards = [];

    // 氣溫卡片
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

    //  流感警示卡片
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

    //  一般 API 警示卡片 (維持原本左右排版邏輯)
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
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: cards.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) => SizedBox(
                width: 180,
                child: cards[index],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 輔助元件
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

  // 子元件：流感卡片
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

  // 子元件：氣溫卡片
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
      width: 220,
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

  // 子元件：一般 Alert 卡片
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

// 適齡繪本
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
              height: 190,
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
                          // 書名
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
  // 精選文章
  Widget _buildArticlesSection() {
    final rawArticles = _apiData?['articles'] as List?;
    if (rawArticles == null || rawArticles.isEmpty) {
      return const Text('暫無文章推薦', style: TextStyle(color: Colors.grey));
    }

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

  // 生長建議
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
// 自定義裁剪器
class TicketClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    double radius = 12.0; // 挖掉半圓的半徑
    double vOffset = 120.0;

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