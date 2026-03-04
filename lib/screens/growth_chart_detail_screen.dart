import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../config/theme.dart';
import '../service/database_helper.dart';
import '../service/growth_data_service.dart';

class GrowthChartDetailScreen extends StatefulWidget {
  final DateTime babyBirthDate;
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
        _growthRecords.sort((a, b) => a['time'].compareTo(b['time']));
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                '生長曲線分析',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF4A0E0E)),
              ),
              // 使用 Spacer 讓中間的內容自動推到垂直中心
              const Spacer(), 
              
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                ),
                child: _isLoading 
                  ? const Center(child: CircularProgressIndicator())
                  : AspectRatio(
                      aspectRatio: 1.0, // 強制正方形
                      child: _growthRecords.isEmpty 
                        ? const Center(child: Text('目前尚無紀錄', style: TextStyle(color: Colors.grey)))
                        : LineChart(_buildBmiChartData()),
                    ),
              ),

              const Spacer(), // 下方也放一個 Spacer 達成完美置中

              TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_left, color: Color(0xFF4A0E0E)),
                label: const Text('回上頁', style: TextStyle(fontSize: 18, color: Color(0xFF4A0E0E))),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  LineChartData _buildBmiChartData() {
    final referenceData = GrowthDataService.boyBmiReference;
    List<FlSpot> babyBmiSpots = [];
    
    final RegExp heightExp = RegExp(r'身高:\s*([\d.]+)\s*cm');
    final RegExp weightExp = RegExp(r'體重:\s*([\d.]+)\s*kg');

    for (var record in _growthRecords) {
      final hMatch = heightExp.firstMatch(record['value'] ?? "");
      final wMatch = weightExp.firstMatch(record['value'] ?? "");
      if (hMatch != null && wMatch != null) {
        double heightM = (double.tryParse(hMatch.group(1)!) ?? 0) / 100;
        double weightKg = double.tryParse(wMatch.group(1)!) ?? 0;
        if (heightM > 0) {
          double bmi = weightKg / (heightM * heightM);
          DateTime recordTime = DateTime.parse(record['time']);
          double ageInYears = recordTime.difference(widget.babyBirthDate).inDays / 365.0;
          babyBmiSpots.add(FlSpot(ageInYears, double.parse(bmi.toStringAsFixed(2))));
        }
      }
    }

    // 動態計算邊界確保線條不跑出去
    double maxX = 5.0;
    for (var ref in referenceData) { if (ref['age'] > maxX) maxX = ref['age'].toDouble(); }
    for (var spot in babyBmiSpots) { if (spot.x > maxX) maxX = spot.x; }
    maxX = (maxX + 0.5).ceilToDouble();

    double maxY = 22.0;
    for (var ref in referenceData) { if (ref['p97'] > maxY) maxY = ref['p97'].toDouble(); }
    for (var spot in babyBmiSpots) { if (spot.y > maxY) maxY = spot.y; }
    maxY = (maxY + 2.0).ceilToDouble();

    return LineChartData(
      minX: 0,
      maxX: maxX,
      minY: 10,
      maxY: maxY,
      // 小格子網格設定
      gridData: FlGridData(
        show: true,
        horizontalInterval: 1.0, 
        verticalInterval: 0.5,   
        getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1),
        getDrawingVerticalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true, 
            interval: 1.0, 
            getTitlesWidget: (value, meta) => Text('${value.toInt()}歲', style: const TextStyle(fontSize: 10)),
          ),
        ),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 2.0, reservedSize: 30)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      lineBarsData: [
        _buildRefLine(referenceData, 'p97', Colors.red),
        _buildRefLine(referenceData, 'p50', Colors.green),
        _buildRefLine(referenceData, 'p3', Colors.orange),
        LineChartBarData(
          spots: babyBmiSpots,
          isCurved: true,
          color: AppTheme.primaryColor,
          barWidth: 4,
          dotData: const FlDotData(show: true),
        ),
      ],
    );
  }

  LineChartBarData _buildRefLine(List<Map<String, dynamic>> data, String key, Color color) {
    return LineChartBarData(
      spots: data.map((e) => FlSpot(e['age'].toDouble(), e[key].toDouble())).toList(),
      color: color.withOpacity(0.4),
      dashArray: [5, 5],
      dotData: const FlDotData(show: false),
    );
  }
}