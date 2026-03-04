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
      // 1. 移除原本的 AppBar
      backgroundColor: Colors.transparent, 
      body: Stack(
        children: [
          // 2. 背景設定 (格紋與頂部裝飾)
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('image/background.png'),
                repeat: ImageRepeat.repeat,
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Image.asset(
              'image/bg1.png', 
              fit: BoxFit.fitWidth,
            ),
          ),

          // 3. 主要內容區塊
          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : CustomScrollView(
                    slivers: [
                      // 大標題區塊：模仿 RecordsScreen 樣式
                      SliverToBoxAdapter(
                        child: Container(
                          padding: const EdgeInsets.only(top: 40, left: 24, bottom: 20),
                          child: const Text(
                            '歷史趨勢分析',
                            style: TextStyle(
                              fontSize: 32, 
                              fontWeight: FontWeight.bold, 
                              color: Color(0xFF4F000B),
                            ),
                          ),
                        ),
                      ),

                      // 圖表列表
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            _buildChartCard(
                              title: '體溫變化',
                              icon: Icons.thermostat,
                              color: Colors.redAccent,
                              type: 'health_temp',
                              chart: _buildTempChart(),
                            ),
                            const SizedBox(height: 20),
                            _buildChartCard(
                              title: '體重成長',
                              icon: Icons.straighten,
                              color: Colors.green,
                              type: 'growth_body',
                              chart: _buildWeightChart(),
                            ),
                            const SizedBox(height: 20),
                            _buildChartCard(
                              title: '睡眠時數',
                              icon: Icons.bed,
                              color: Colors.indigo,
                              type: 'routine_sleep',
                              chart: _buildSleepChart(),
                            ),
                            const SizedBox(height: 20),
                            _buildOtherCard(),
                            const SizedBox(height: 40),
                          ]),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
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
    return Container(
      // 1. 加上與專案風格一致的橘色大外框
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5EA), // 淺米色背景
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFFF8C00), // 橘色邊框
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 2. 標題與「詳細記錄」按鈕列
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: const Color(0xFF4A0E0E)), // 使用深褐色圖示保持色調一致
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4A0E0E),
                    ),
                  ),
                ],
              ),
              // 3. 右上角的「詳細記錄」文字按鈕
              TextButton(
                onPressed: () => _navigateToDetail(title, type),
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  '詳細記錄 >>',
                  style: TextStyle(
                    color: Color(0xFFFF8C00), // 橘色文字
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 4. 圖表內容區塊 (移除了 Card，改用 Container 裝載以利排版)
          Container(
            height: 200,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: chart,
          ),
        ],
      ),
    );
  }

Widget _buildOtherCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5EA),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFF8C00), width: 2),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: const Icon(Icons.category, color: Color(0xFF4A0E0E)),
        title: const Text(
          '其他紀錄 (疫苗、里程碑)',
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A0E0E)),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFFFF8C00)),
        onTap: () => _navigateToDetail('其他', 'others'),
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
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('image/background.png'),
                fit: BoxFit.cover,
                repeat: ImageRepeat.repeat,
              ),
            ),
          ),
          Positioned(
            top: 0, left: 0, right: 0,
            child: Image.asset('image/bg1.png', fit: BoxFit.fitWidth),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 返回按鈕
                Padding(
                  padding: const EdgeInsets.only(top: 10, left: 10),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF4F000B)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                // 與紀錄頁一致的大標題
                Padding(
                  padding: const EdgeInsets.only(left: 24, bottom: 20),
                  child: Text(
                    '${widget.title}紀錄',
                    style: const TextStyle(
                      fontSize: 32, 
                      fontWeight: FontWeight.bold, 
                      color: Color(0xFF4F000B),
                    ),
                  ),
                ),
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
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
                  )
                )
        ]),
          ),
        ],
        
        
        
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