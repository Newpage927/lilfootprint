import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../service/growth_data_service.dart';

class BmiChartScreen extends StatelessWidget {
  // 接收與原本首頁/紀錄頁相同的生長紀錄資料格式
  final List<Map<String, dynamic>> growthRecords;
  final DateTime babyBirthDate;
  const BmiChartScreen({
    super.key, 
    required this.growthRecords, 
    required this.babyBirthDate, 
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('生長趨勢分析', style: TextStyle(color: Color(0xFF4A0E0E), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF4A0E0E)),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('image/background.png'), // 全域背景圖
            fit: BoxFit.cover,
            repeat: ImageRepeat.repeat,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // 第一張圖：身高曲線
                _buildChartCard(
                  title: '身高成長趨勢 (cm)',
                  chart: _buildGrowthChart(isHeight: true),
                ),
                const SizedBox(height: 20),
                // 第二張圖：體重曲線
                _buildChartCard(
                  title: '體重成長趨勢 (kg)',
                  chart: _buildGrowthChart(isHeight: false),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 封裝卡片樣式
  Widget _buildChartCard({required String title, required Widget chart}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFDEFD5), width: 1.5),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4A0E0E))),
          const SizedBox(height: 16),
          SizedBox(height: 250, child: chart),
        ],
      ),
    );
  }

  // 核心圖表構建邏輯
  Widget _buildGrowthChart({required bool isHeight}) {
    if (growthRecords.isEmpty) return const Center(child: Text('目前尚無資料'));

    final RegExp heightExp = RegExp(r'身高:\s*([\d.]+)\s*cm');
    final RegExp weightExp = RegExp(r'體重:\s*([\d.]+)\s*kg');
    List<ChartData> userSpots = [];

    // 解析用戶紀錄
    for (var record in growthRecords) {
      final valueStr = record['value'] ?? "";
      final hMatch = heightExp.firstMatch(valueStr);
      final wMatch = weightExp.firstMatch(valueStr);
      double? val = isHeight 
          ? double.tryParse(hMatch?.group(1) ?? "") 
          : double.tryParse(wMatch?.group(1) ?? "");
      
      if (val != null) {
        DateTime dt = DateTime.parse(record['time']);
        double age = dt.difference(babyBirthDate).inDays / 365.0;
        userSpots.add(ChartData(age, val));
      }
    }

    // 1. 取得身高體重參考數據 (對應您更新後的 GrowthDataService)
    final refData = GrowthDataService.boyGrowthReference; 

    return SfCartesianChart(
      primaryXAxis: NumericAxis(
        title: AxisTitle(text: '年齡 (歲)', textStyle: const TextStyle(fontSize: 12)),
        majorGridLines: const MajorGridLines(width: 0.5, dashArray: [5, 5]),
      ),
      primaryYAxis: NumericAxis(
        title: AxisTitle(text: isHeight ? '身高 (cm)' : '體重 (kg)'),
      ),
      legend: const Legend(isVisible: true, position: LegendPosition.bottom), // 顯示圖例
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <CartesianSeries>[
        // --- PR97 參考線 (紅色虛線) ---
        SplineSeries<Map<String, dynamic>, double>(
          name: 'PR97',
          dataSource: refData,
          xValueMapper: (data, _) => data['age'],
          yValueMapper: (data, _) => isHeight ? data['p97_h'] : data['p97_w'],
          dashArray: const [5, 5],
          color: Colors.red.withOpacity(0.3),
        ),
        // --- PR50 參考線 (綠色虛線) ---
        SplineSeries<Map<String, dynamic>, double>(
          name: 'PR50',
          dataSource: refData,
          xValueMapper: (data, _) => data['age'],
          yValueMapper: (data, _) => isHeight ? data['p50_h'] : data['p50_w'],
          dashArray: const [5, 5],
          color: Colors.green.withOpacity(0.3),
        ),
        // --- PR3 參考線 (橘色虛線) ---
        SplineSeries<Map<String, dynamic>, double>(
          name: 'PR3',
          dataSource: refData,
          xValueMapper: (data, _) => data['age'],
          yValueMapper: (data, _) => isHeight ? data['p3_h'] : data['p3_w'],
          dashArray: const [5, 5],
          color: Colors.orange.withOpacity(0.3),
        ),
        // --- 寶寶實際曲線 (實線) ---
        SplineSeries<ChartData, double>(
          name: '寶寶紀錄',
          dataSource: userSpots,
          xValueMapper: (data, _) => data.x,
          yValueMapper: (data, _) => data.y,
          color: isHeight ? Colors.blue : const Color(0xFFF98C12),
          width: 3,
          markerSettings: const MarkerSettings(isVisible: true),
          dataLabelSettings: const DataLabelSettings(isVisible: true),
        ),
      ],
    );
  }
}

class ChartData {
  ChartData(this.x, this.y);
  final double x;
  final double y;
}