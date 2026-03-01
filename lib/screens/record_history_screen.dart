import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../service/database_helper.dart';
// 若無此檔案，可移除並將顏色改為 Colors.blue

class RecordHistoryScreen extends StatefulWidget {
  const RecordHistoryScreen({super.key});

  @override
  State<RecordHistoryScreen> createState() => _RecordHistoryScreenState();
}

class _RecordHistoryScreenState extends State<RecordHistoryScreen> {
  // 存放所有資料
  List<Map<String, dynamic>> _allRecords = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // 讀取資料庫
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.readAllRecords();
    setState(() {
      _allRecords = data;
      _isLoading = false;
    });
  }

  // 導航到詳細頁面，並在返回時刷新圖表 (因為可能刪除了資料)
  void _navigateToDetail(String title, String type) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecordDetailScreen(title: title, filterType: type),
      ),
    );
    _loadData(); // 返回後刷新資料
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('歷史趨勢')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allRecords.isEmpty
              ? const Center(child: Text('目前沒有紀錄'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // 1. 體溫圖表卡片
                      _buildChartCard(
                        title: '體溫變化',
                        icon: Icons.thermostat,
                        color: Colors.redAccent,
                        type: 'health_temp',
                        chart: _buildTempChart(),
                      ),
                      const SizedBox(height: 16),
                      
                      // 2. 成長曲線卡片 (體重)
                      _buildChartCard(
                        title: '體重成長',
                        icon: Icons.straighten,
                        color: Colors.green,
                        type: 'growth_body',
                        chart: _buildWeightChart(),
                      ),
                      const SizedBox(height: 16),
                      
                      // 3. 睡眠時數卡片
                      _buildChartCard(
                        title: '睡眠時數',
                        icon: Icons.bed,
                        color: Colors.indigo,
                        type: 'routine_sleep',
                        chart: _buildSleepChart(),
                      ),
                      const SizedBox(height: 16),
                      
                      // 4. 其他紀錄 (疫苗、里程碑等)
                      _buildOtherCard(),
                    ],
                  ),
                ),
    );
  }

  // --- UI 元件：圖表卡片外框 ---
  Widget _buildChartCard({
    required String title,
    required IconData icon,
    required Color color,
    required String type,
    required Widget chart,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _navigateToDetail(title, type),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: color),
                      const SizedBox(width: 8),
                      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                ],
              ),
              const Divider(),
              SizedBox(height: 200, child: chart), // 圖表高度
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtherCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const Icon(Icons.category, color: Colors.orange),
        title: const Text('其他紀錄 (疫苗、里程碑)'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _navigateToDetail('其他紀錄', 'others'),
      ),
    );
  }

  // --- 圖表邏輯：體溫折線圖 ---
  Widget _buildTempChart() {
    final data = _allRecords.where((r) => r['type'] == 'health_temp').toList();
    // 排序：舊 -> 新
    data.sort((a, b) => a['time'].compareTo(b['time']));
    
    if (data.isEmpty) return const Center(child: Text('無資料', style: TextStyle(color: Colors.grey)));

    List<FlSpot> spots = [];
    for (int i = 0; i < data.length; i++) {
      final valStr = (data[i]['value'] as String).replaceAll('°C', '');
      final val = double.tryParse(valStr) ?? 0;
      spots.add(FlSpot(i.toDouble(), val));
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false), // 簡約模式，不顯示座標軸文字
        borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade200)),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.redAccent,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: Colors.redAccent.withOpacity(0.1)),
          ),
        ],
      ),
    );
  }

  // --- 圖表邏輯：體重折線圖 ---
  Widget _buildWeightChart() {
    final data = _allRecords.where((r) => r['type'] == 'growth_body').toList();
    data.sort((a, b) => a['time'].compareTo(b['time']));

    if (data.isEmpty) return const Center(child: Text('無資料', style: TextStyle(color: Colors.grey)));

    List<FlSpot> spots = [];
    final RegExp regExp = RegExp(r'體重:([\d.]+)kg');

    for (int i = 0; i < data.length; i++) {
      final match = regExp.firstMatch(data[i]['value']);
      if (match != null) {
        final val = double.tryParse(match.group(1)!) ?? 0;
        spots.add(FlSpot(i.toDouble(), val));
      }
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade200)),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.green,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: Colors.green.withOpacity(0.1)),
          ),
        ],
      ),
    );
  }

  // --- 圖表邏輯：睡眠長條圖 ---
  Widget _buildSleepChart() {
    final data = _allRecords.where((r) => r['type'] == 'routine_sleep').toList();
    data.sort((a, b) => a['time'].compareTo(b['time']));

    if (data.isEmpty) return const Center(child: Text('無資料', style: TextStyle(color: Colors.grey)));

    // 取最近 7 筆，避免圖表太擠
    final recentData = data.length > 10 ? data.sublist(data.length - 10) : data;

    List<BarChartGroupData> barGroups = [];
    for (int i = 0; i < recentData.length; i++) {
      String valStr = recentData[i]['value'];
      double hours = 0;
      final hIndex = valStr.indexOf('小時');
      final mIndex = valStr.indexOf('分');
      
      if (hIndex != -1) {
        hours += double.tryParse(valStr.substring(0, hIndex)) ?? 0;
        if (mIndex != -1) {
          final mins = double.tryParse(valStr.substring(hIndex + 2, mIndex)) ?? 0;
          hours += mins / 60;
        }
      }
      barGroups.add(BarChartGroupData(
        x: i,
        barRods: [BarChartRodData(toY: hours, color: Colors.indigo, width: 12, borderRadius: BorderRadius.circular(2))],
      ));
    }

    return BarChart(
      BarChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: barGroups,
      ),
    );
  }
}

// ==========================================
// 第二層頁面：詳細列表 (包含刪除功能)
// ==========================================
class RecordDetailScreen extends StatefulWidget {
  final String title;
  final String filterType; // 用來過濾顯示哪一類的資料

  const RecordDetailScreen({super.key, required this.title, required this.filterType});

  @override
  State<RecordDetailScreen> createState() => _RecordDetailScreenState();
}

class _RecordDetailScreenState extends State<RecordDetailScreen> {
  late Future<List<Map<String, dynamic>>> _recordsFuture;

  @override
  void initState() {
    super.initState();
    _refreshRecords();
  }

  void _refreshRecords() {
    setState(() {
      _recordsFuture = DatabaseHelper.instance.readAllRecords();
    });
  }

  Future<void> _deleteItem(int id) async {
    await DatabaseHelper.instance.deleteRecord(id);
    _refreshRecords();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('紀錄已刪除')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.title}紀錄')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _recordsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('沒有資料'));
          }

          // 這裡進行過濾：只顯示符合 filterType 的資料
          final allRecords = snapshot.data!;
          final filteredRecords = widget.filterType == 'others'
              ? allRecords.where((r) => !['health_temp', 'growth_body', 'routine_sleep'].contains(r['type'])).toList()
              : allRecords.where((r) => r['type'] == widget.filterType).toList();

          if (filteredRecords.isEmpty) {
            return const Center(child: Text('此類別目前沒有紀錄'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredRecords.length,
            itemBuilder: (context, index) {
              final record = filteredRecords[index];
              final id = record['id'];
              final value = record['value'];
              final note = record['note'];
              final timeString = record['time'];
              
              final DateTime dt = DateTime.parse(timeString);
              final String formattedTime = "${dt.year}/${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";

              return Dismissible(
                key: Key(id.toString()),
                background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
                onDismissed: (direction) => _deleteItem(id),
                child: Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey.shade200,
                      child: Icon(_getIcon(widget.filterType), color: Colors.black54, size: 20),
                    ),
                    title: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (note != null && note.isNotEmpty)
                          Text(note, style: TextStyle(color: Colors.grey.shade600)),
                        const SizedBox(height: 4),
                        Text(formattedTime, style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'health_temp': return Icons.thermostat;
      case 'growth_body': return Icons.straighten;
      case 'routine_sleep': return Icons.bed;
      default: return Icons.list;
    }
  }
}