import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // 需在 pubspec.yaml 加入 intl
import '../config/theme.dart';
import '../service/database_helper.dart';
import 'record_history_screen.dart';

// 定義疫苗類型 Enum
enum VaccineType { bcg, hepB, fiveInOne, pneumococcal, flu, rotavirus, japaneseEnc, other }

extension VaccineExtension on VaccineType {
  String get label {
    switch (this) {
      case VaccineType.bcg: return '卡介苗';
      case VaccineType.hepB: return 'B型肝炎';
      case VaccineType.fiveInOne: return '五合一';
      case VaccineType.pneumococcal: return '肺炎鏈球菌';
      case VaccineType.flu: return '流感疫苗';
      case VaccineType.rotavirus: return '輪狀病毒';
      case VaccineType.japaneseEnc: return '日本腦炎';
      case VaccineType.other: return '其他疫苗';
    }
  }
}

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('詳細育兒紀錄'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.black87),
            tooltip: '查看歷史',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RecordHistoryScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 生理成長 (身高、體重)
            _buildSectionHeader('生理成長', Icons.show_chart),
            _buildGrid(context, [
              _RecordItem('身高/體重', Icons.straighten, Colors.green.shade100, 'growth_body'),
            ]),
            
            const SizedBox(height: 24),

            // 2. 日常作息 (睡眠)
            _buildSectionHeader('日常作息', Icons.access_time),
            _buildGrid(context, [
              _RecordItem('睡眠紀錄', Icons.bed, Colors.indigo.shade100, 'routine_sleep'),
              // 如果你要保留奶量、排泄，可以加回來，這裡先專注於你的新需求
            ]),
            
            const SizedBox(height: 24),

            // 3. 健康醫療 (體溫、疫苗)
            _buildSectionHeader('健康醫療', Icons.medical_services),
            _buildGrid(context, [
              _RecordItem('體溫', Icons.thermostat, Colors.red.shade100, 'health_temp'),
              _RecordItem('疫苗接種', Icons.vaccines, Colors.blue.shade100, 'health_vaccine'),
            ]),

            const SizedBox(height: 24),

            // 4. 發展里程碑
            _buildSectionHeader('發展里程碑', Icons.flag),
            _buildGrid(context, [
              _RecordItem('動作發展', Icons.directions_run, Colors.purple.shade100, 'growth_milestone'),
            ]),
          ],
        ),
      ),
    );
  }

  // --- UI 建構區塊 ---
  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.subTextColor),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textColor)),
        ],
      ),
    );
  }

  Widget _buildGrid(BuildContext context, List<_RecordItem> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, // 改成 3 欄比較寬敞
        childAspectRatio: 1.0,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return InkWell(
          onTap: () => _showRecordForm(context, item),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, 2))
              ],
              border: Border.all(color: item.color.withOpacity(0.5), width: 1),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(item.icon, color: Colors.black87, size: 28),
                ),
                const SizedBox(height: 8),
                Text(item.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- 🔥 核心邏輯：彈出表單 ---
  void _showRecordForm(BuildContext context, _RecordItem item) {
    // 控制器與變數
    final TextEditingController heightController = TextEditingController();
    final TextEditingController weightController = TextEditingController();
    final TextEditingController tempController = TextEditingController();
    
    // 睡眠專用變數
    DateTime sleepStart = DateTime.now();
    DateTime sleepEnd = DateTime.now().add(const Duration(hours: 1));
    
    // 疫苗專用變數
    VaccineType selectedVaccine = VaccineType.fiveInOne;
    DateTime vaccineDate = DateTime.now();

    // 里程碑專用變數 (這裡簡化為選擇一個動作並紀錄日期)
    String selectedMilestone = '翻身';
    DateTime milestoneDate = DateTime.now();
    final List<String> milestones = ['翻身', '坐', '爬', '走'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            
            // 內部函式：選擇日期時間
            Future<void> pickDateTime(bool isStart) async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 1)),
              );
              if (date == null) return;
              if(!context.mounted) return;
              
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.now(),
              );
              if (time == null) return;

              final result = DateTime(date.year, date.month, date.day, time.hour, time.minute);
              setSheetState(() {
                if (isStart) sleepStart = result; else sleepEnd = result;
              });
            }

            // 內部函式：單純選擇日期
            Future<void> pickDate(Function(DateTime) onPicked) async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (date != null) {
                setSheetState(() => onPicked(date));
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20, right: 20, top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(item.icon, color: AppTheme.primaryColor),
                      const SizedBox(width: 10),
                      Text(item.label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 10),

                  // --- 根據類型顯示不同表單 ---
                  if (item.type == 'growth_body') ...[
                    _buildNumberInput('身高', 'cm', heightController),
                    const SizedBox(height: 16),
                    _buildNumberInput('體重', 'kg', weightController),
                  ] 
                  else if (item.type == 'routine_sleep') ...[
                     ListTile(
                      title: const Text('入睡時間'),
                      subtitle: Text(DateFormat('yyyy/MM/dd HH:mm').format(sleepStart)),
                      trailing: const Icon(Icons.edit_calendar),
                      onTap: () => pickDateTime(true),
                      shape: _roundedBorder(),
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      title: const Text('起床時間'),
                      subtitle: Text(DateFormat('yyyy/MM/dd HH:mm').format(sleepEnd)),
                      trailing: const Icon(Icons.edit_calendar),
                      onTap: () => pickDateTime(false),
                      shape: _roundedBorder(),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        '總時數: ${sleepEnd.difference(sleepStart).inHours} 小時 ${sleepEnd.difference(sleepStart).inMinutes % 60} 分鐘',
                        style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ]
                  else if (item.type == 'health_temp') ...[
                    _buildNumberInput('體溫', '°C', tempController),
                  ]
                  else if (item.type == 'health_vaccine') ...[
                    DropdownButtonFormField<VaccineType>(
                      value: selectedVaccine,
                      decoration: const InputDecoration(labelText: '疫苗名稱', border: OutlineInputBorder()),
                      items: VaccineType.values.map((v) => DropdownMenuItem(value: v, child: Text(v.label))).toList(),
                      onChanged: (val) => setSheetState(() => selectedVaccine = val!),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: const Text('施打日期'),
                      trailing: Text(DateFormat('yyyy/MM/dd').format(vaccineDate), style: const TextStyle(fontSize: 16)),
                      onTap: () => pickDate((d) => vaccineDate = d),
                      shape: _roundedBorder(),
                    ),
                  ]
                  else if (item.type == 'growth_milestone') ...[
                    const Text('達成項目:'),
                    Wrap(
                      spacing: 8,
                      children: milestones.map((m) => ChoiceChip(
                        label: Text(m),
                        selected: selectedMilestone == m,
                        onSelected: (val) => setSheetState(() => selectedMilestone = m),
                      )).toList(),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: const Text('達成日期'),
                      trailing: Text(DateFormat('yyyy/MM/dd').format(milestoneDate), style: const TextStyle(fontSize: 16)),
                      onTap: () => pickDate((d) => milestoneDate = d),
                      shape: _roundedBorder(),
                    ),
                  ],

                  const SizedBox(height: 24),
                  
                  // 儲存按鈕
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        // 1. 組合資料
                        String finalValue = "";
                        String finalNote = "";
                        String finalTime = DateTime.now().toIso8601String(); // 預設現在

                        if (item.type == 'growth_body') {
                          final h = heightController.text;
                          final w = weightController.text;
                          if (h.isEmpty && w.isEmpty) return;
                          finalValue = "身高:${h}cm, 體重:${w}kg";
                        } 
                        else if (item.type == 'routine_sleep') {
                          // 特殊處理：Time欄位存入睡，Note欄位存起床
                          finalTime = sleepStart.toIso8601String(); 
                          finalNote = sleepEnd.toIso8601String(); // 將起床時間存入備註
                          
                          // 計算時數存入 Value 方便顯示
                          final diff = sleepEnd.difference(sleepStart);
                          finalValue = "${diff.inHours}小時${diff.inMinutes % 60}分"; 
                        }
                        else if (item.type == 'health_temp') {
                          if (tempController.text.isEmpty) return;
                          finalValue = "${tempController.text}°C";
                        }
                        else if (item.type == 'health_vaccine') {
                          finalValue = selectedVaccine.label;
                          finalTime = vaccineDate.toIso8601String();
                        }
                        else if (item.type == 'growth_milestone') {
                          finalValue = selectedMilestone; // 例如 "翻身"
                          finalTime = milestoneDate.toIso8601String();
                          finalNote = "達成";
                        }

                        // 2. 存入資料庫
                        await DatabaseHelper.instance.createRecord(
                          item.type, 
                          finalValue, 
                          finalNote, 
                          customTime: DateTime.parse(finalTime) // 這樣歷史紀錄的時間就會是你選的時間
                        );
                        
                        // 若是改了時間（如補登疫苗），這裡需要更精細的DB操作，
                        // 但 DatabaseHelper.createRecord 目前只支援當下時間或需要改寫。
                        // 為了不改動 DB Helper，我們這裡如果是「過去的時間」，可能需要手動 SQL，
                        // 但為了簡單，我們先依然用 createRecord，但這會導致 DB 內的 time 欄位是「紀錄當下」。
                        // --- 進階修補 ---
                        // 如果真的很在意「事件發生時間」vs「紀錄時間」，建議修改 DatabaseHelper 的 createRecord 
                        // 讓它可以接收 time 參數。目前我們先依賴 createRecord 的預設行為，
                        // 唯獨「疫苗」和「里程碑」這種明確選日期的，我們希望列表顯示的是那一天。
                        // (註：下面我會提供一個小技巧來修正這點)

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('已儲存: $finalValue')),
                          );
                        }
                      },
                      child: const Text('儲存紀錄', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            );
          }
        );
      },
    );
  }

  // --- 輔助 Widget ---
  Widget _buildNumberInput(String label, String unit, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        suffixText: unit,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
  
  ShapeBorder _roundedBorder() {
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8), 
      side: BorderSide(color: Colors.grey.shade300),
    );
  }
}

// 資料類別
class _RecordItem {
  final String label;
  final IconData icon;
  final Color color;
  final String type;

  _RecordItem(this.label, this.icon, this.color, this.type);
}