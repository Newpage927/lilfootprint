import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../service/database_helper.dart';

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
      backgroundColor: Colors.transparent, 
      body: Stack(
        children: [
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

          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.only(top: 40, left: 24, bottom: 20),
                    child: const Text(
                      '詳細育兒紀錄',
                      style: TextStyle(
                        fontSize: 32, 
                        fontWeight: FontWeight.bold, 
                        color: Color(0xFF4F000B),
                      ),
                    ),
                  ),
                ),
                
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.9,
                    ),
                    delegate: SliverChildListDelegate([
                      _buildRecordCard('身高/體重', 'image/owl_growth.png', 'growth_body'),
                      _buildRecordCard('睡眠紀錄', 'image/owl_sleep.png', 'routine_sleep'),
                      _buildRecordCard('體溫', 'image/owl_temp.png', 'health_temp'),
                      _buildRecordCard('疫苗接種', 'image/owl_vaccine.png', 'health_vaccine'),
                    ]),
                  ),
                ),
                
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  sliver: SliverToBoxAdapter(
                    child: _buildLargeRecordCard('發展里程碑', 'image/owl_milestone.png', 'growth_milestone'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildRecordCard(String label, String imagePath, String type) {
    return GestureDetector(
      onTap: () => _showRecordForm(context, _RecordItem(label, Icons.edit, Colors.orange, type)),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFF9F0),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFFF8C00), width: 3),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(imagePath, height: 120, fit: BoxFit.contain),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4F000B))),
          ],
        ),
      ),
    );
  }
  Widget _buildLargeRecordCard(String label, String imagePath, String type) {
    return GestureDetector(
      onTap: () => _showRecordForm(context, _RecordItem(label, Icons.edit, Colors.orange, type)),
      child: Container(
        height: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF9F0),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFFF8C00), width: 3),
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Image.asset(imagePath, width: 80, fit: BoxFit.contain),
            ),
            
            Align(
              alignment: Alignment.center,
              child: Text(
                label, 
                style: const TextStyle(
                  fontSize: 20, 
                  fontWeight: FontWeight.bold, 
                  color: Color(0xFF4F000B),
                ),
              ),
            ),

            Positioned(
              right: 0,
              bottom: 10,
              child: Image.asset(
                'image/footprints.png',
                width: 80,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }

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

    // 里程碑專用變數
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
            
            // 選擇日期時間
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

            // 單純選擇日期
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

                  // 根據類型顯示不同表單
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
                        // 組合資料
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

                        // 存入資料庫
                        await DatabaseHelper.instance.createRecord(
                          item.type, 
                          finalValue, 
                          finalNote, 
                          customTime: DateTime.parse(finalTime)
                        );

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