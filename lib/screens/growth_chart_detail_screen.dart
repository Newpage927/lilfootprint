// lib/screens/growth_chart_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../service/growth_data_service.dart';

class BmiChartScreen extends StatelessWidget {
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
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(image: AssetImage('image/background.png'), repeat: ImageRepeat.repeat),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildChartCard(title: '身高成長趨勢 (cm)', chart: _buildGrowthChart(isHeight: true)),
                const SizedBox(height: 20),
                _buildChartCard(title: '體重成長趨勢 (kg)', chart: _buildGrowthChart(isHeight: false)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGrowthChart({required bool isHeight}) {
    if (growthRecords.isEmpty) return const Center(child: Text('目前尚無資料'));

    // 解析紀錄中的身高與體重數字
    final RegExp heightExp = RegExp(r'身高:([\d.]+)');
    final RegExp weightExp = RegExp(r'體重:([\d.]+)');
    
    List<ChartData> userSpots = [];
    for (var record in growthRecords) {
      final valueStr = record['value'] ?? "";
      final match = isHeight ? heightExp.firstMatch(valueStr) : weightExp.firstMatch(valueStr);
      
      if (match != null) {
        double val = double.parse(match.group(1)!);
        DateTime dt = DateTime.parse(record['time']);
        // 計算月齡作為 X 軸
        double months = dt.difference(babyBirthDate).inDays / 30.44;
        userSpots.add(ChartData(months, val));
      }
    }

    final refData = GrowthDataService.boyReference;

    return SfCartesianChart(
      primaryXAxis: NumericAxis(title: AxisTitle(text: '月齡')),
      primaryYAxis: NumericAxis(title: AxisTitle(text: isHeight ? '身高 (cm)' : '體重 (kg)')),
      legend: const Legend(isVisible: true, position: LegendPosition.bottom),
      series: <CartesianSeries>[
        // PR 參考曲線
        _buildSplineSeries(refData, 'PR97', isHeight ? 'p97_h' : 'p97_w', Colors.red),
        _buildSplineSeries(refData, 'PR50', isHeight ? 'p50_h' : 'p50_w', Colors.green),
        _buildSplineSeries(refData, 'PR3', isHeight ? 'p3_h' : 'p3_w', Colors.orange),
        // 寶寶實際紀錄
        SplineSeries<ChartData, double>(
          name: '寶寶紀錄',
          dataSource: userSpots,
          xValueMapper: (data, _) => data.x,
          yValueMapper: (data, _) => data.y,
          color: Colors.blue,
          width: 4,
          markerSettings: const MarkerSettings(isVisible: true),
        ),
      ],
    );
  }

  SplineSeries<Map<String, dynamic>, double> _buildSplineSeries(List<Map<String, dynamic>> data, String name, String yField, Color color) {
    return SplineSeries<Map<String, dynamic>, double>(
      name: name,
      dataSource: data,
      xValueMapper: (d, _) => d['months'],
      yValueMapper: (d, _) => d[yField],
      dashArray: const [5, 5],
      color: color.withOpacity(0.5),
    );
  }
  
  Widget _buildChartCard({required String title, required Widget chart}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFF8C00), width: 1.5),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SizedBox(height: 250, child: chart),
        ],
      ),
    );
  }
}

class ChartData {
  ChartData(this.x, this.y);
  final double x;
  final double y;
}