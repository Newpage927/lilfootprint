import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../config/theme.dart';
import '../service/database_helper.dart';
import '../service/growth_data_service.dart';

class GrowthChartDetailScreen extends StatefulWidget {
  final DateTime babyBirthDate; // 定義接收生日的變數
  const GrowthChartDetailScreen({super.key, required this.babyBirthDate});

  @override
  State<GrowthChartDetailScreen> createState() => _GrowthChartDetailScreenState();
}

class _GrowthChartDetailScreenState extends State<GrowthChartDetailScreen> {
  List<Map<String, dynamic>> _growthRecords = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGrowthData();
  }

  Future<void> _loadGrowthData() async {
    final allRecords = await DatabaseHelper.instance.readAllRecords();
    if (mounted) {
      setState(() {
        _growthRecords = allRecords.where((r) => r['type'] == 'growth_body').toList();
        _growthRecords.sort((a, b) => a['time'].compareTo(b['time'])); // 時間由舊到新
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 套用與主程式一致的背景裝飾
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('image/background.png'),
            fit: BoxFit.cover,
            repeat: ImageRepeat.repeat,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              const Text(
                '生長曲線',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF4A0E0E)),
              ),
              const SizedBox(height: 20),
              // 模擬圖片 2 的白色圓角大卡片
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                  ),
                  child: _isLoading 
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        children: [
                          // 圖表實作 (保留原有的 BMI 邏輯)
                          Expanded(
                            child: _growthRecords.isEmpty 
                              ? const Center(child: Text('尚無身高體重紀錄'))
                              : LineChart(_buildBmiChartData()), 
                          ),
                          const SizedBox(height: 20),
                          // 回上頁按鈕
                          TextButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_left, color: Color(0xFF4A0E0E)),
                            label: const Text('回上頁', style: TextStyle(fontSize: 18, color: Color(0xFF4A0E0E))),
                          ),
                        ],
                      ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // 這裡放入你原本在 HomeScreen 裡的 _buildBmiChartData 函式內容
  final referenceData = GrowthDataService.boyBmiReference;
  // 2. 修改圖表構建邏輯
  LineChartData _buildBmiChartData() {
  List<FlSpot> babyBmiSpots = [];
  
  // 正則表達式解析 "身高:170cm, 體重:60kg"
  final RegExp heightExp = RegExp(r'身高:([\d.]+)cm');
  final RegExp weightExp = RegExp(r'體重:([\d.]+)kg');

  for (var record in _growthRecords) {
    final hMatch = heightExp.firstMatch(record['value']);
    final wMatch = weightExp.firstMatch(record['value']);
    
    if (hMatch != null && wMatch != null) {
      double heightM = (double.tryParse(hMatch.group(1)!) ?? 0) / 100; // 轉為公尺
      double weightKg = double.tryParse(wMatch.group(1)!) ?? 0;
      
      if (heightM > 0) {
        double bmi = weightKg / (heightM * heightM);
        
        // 計算該紀錄時的年齡 (歲)
        DateTime recordTime = DateTime.parse(record['time']);
        double ageInYears = recordTime.difference(widget.babyBirthDate).inDays / 365.0;
        
        babyBmiSpots.add(FlSpot(ageInYears, double.parse(bmi.toStringAsFixed(2))));
      }
    }
  }

  return LineChartData(
    minX: 0,
    maxX: 5, // 設定顯示到 5 歲
    minY: 10,
    maxY: 22,
    titlesData: FlTitlesData(
      bottomTitles: AxisTitles(
        axisNameWidget: const Text('年齡 (歲)', style: TextStyle(fontSize: 10)),
        sideTitles: SideTitles(showTitles: true, reservedSize: 22),
      ),
      leftTitles: AxisTitles(
        axisNameWidget: const Text('BMI', style: TextStyle(fontSize: 10)),
        sideTitles: SideTitles(showTitles: true, reservedSize: 30),
      ),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    ),
    lineBarsData: [
      // 背景參考線：第 97 百分位 (肥胖警示)
      LineChartBarData(
        spots: referenceData.map((e) => FlSpot(e['age'], e['p97'])).toList(),
        color: Colors.red.withOpacity(0.3),
        dashArray: [5, 5],
        dotData: const FlDotData(show: false),
      ),
      // 背景參考線：第 50 百分位 (標準中位數)
      LineChartBarData(
        spots: referenceData.map((e) => FlSpot(e['age'], e['p50'])).toList(),
        color: Colors.green.withOpacity(0.3),
        dashArray: [5, 5],
        dotData: const FlDotData(show: false),
      ),
      // 背景參考線：第 3 百分位 (過輕警示)
      LineChartBarData(
        spots: referenceData.map((e) => FlSpot(e['age'], e['p3'])).toList(),
        color: Colors.orange.withOpacity(0.3),
        dashArray: [5, 5],
        dotData: const FlDotData(show: false),
      ),
      // 寶寶的實際 BMI 曲線
      LineChartBarData(
        spots: babyBmiSpots,
        isCurved: true,
        color: AppTheme.primaryColor,
        barWidth: 4,
        dotData: const FlDotData(show: true),
        belowBarData: BarAreaData(show: true, color: AppTheme.primaryColor.withOpacity(0.1)),
      ),
    ],
  );
}
}