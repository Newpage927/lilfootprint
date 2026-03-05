// lib/service/growth_data_service.dart

class GrowthDataService {
  // 男童 BMI 參考數據 (3rd, 50th, 97th 百分位)
  static const List<Map<String, dynamic>> boyReference = [
    {
      'months': 0.0, 
      'p3_h': 46.1, 'p50_h': 49.9, 'p97_h': 53.7, // 身高 cm
      'p3_w': 2.4,  'p50_w': 3.3,  'p97_w': 4.3    // 體重 kg
    },
    {
      'months': 3.0, 
      'p3_h': 57.3, 'p50_h': 61.4, 'p97_h': 65.5,
      'p3_w': 5.0,  'p50_w': 6.4,  'p97_w': 8.0
    },
    {
      'months': 6.0, 
      'p3_h': 63.3, 'p50_h': 67.6, 'p97_h': 71.9,
      'p3_w': 6.4,  'p50_w': 7.9,  'p97_w': 9.8
    },
    // ... 依此類推增加更多月份數據
  ];
  // 女童 BMI 參考數據 (依據您的 ODS 檔案計算結果)
  static const List<Map<String, dynamic>> girlReference = [
    {
      'months': 0.0, 
      'p3_h': 46.1, 'p50_h': 49.9, 'p97_h': 53.7, // 身高 cm
      'p3_w': 2.4,  'p50_w': 3.3,  'p97_w': 4.3    // 體重 kg
    },
    {
      'months': 3.0, 
      'p3_h': 57.3, 'p50_h': 61.4, 'p97_h': 65.5,
      'p3_w': 5.0,  'p50_w': 6.4,  'p97_w': 8.0
    },
    {
      'months': 6.0, 
      'p3_h': 63.3, 'p50_h': 67.6, 'p97_h': 71.9,
      'p3_w': 6.4,  'p50_w': 7.9,  'p97_w': 9.8
    },
    // ... 依此類推增加更多月份數據
  ];

  // 輔助函式：根據性別獲取數據
  static List<Map<String, dynamic>> getReference(String gender) {
    return gender == 'boy' ? boyReference : girlReference;
  }
}