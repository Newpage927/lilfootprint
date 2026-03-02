// lib/service/growth_data_service.dart

class GrowthDataService {
  // 男童 BMI 參考數據 (3rd, 50th, 97th 百分位)
  static const List<Map<String, dynamic>> boyBmiReference = [
    {'age': 0.0, 'p3': 11.66, 'p50': 13.25, 'p97': 15.08},
    {'age': 0.5, 'p3': 15.82, 'p50': 17.29, 'p97': 18.92},
    {'age': 1.0, 'p3': 15.34, 'p50': 16.75, 'p97': 18.35},
    {'age': 1.5, 'p3': 14.93, 'p50': 16.09, 'p97': 17.71},
    {'age': 2.0, 'p3': 14.54, 'p50': 15.83, 'p97': 17.24},
    {'age': 3.0, 'p3': 14.36, 'p50': 15.48, 'p97': 16.93},
    {'age': 5.0, 'p3': 13.96, 'p50': 15.12, 'p97': 16.89},
    {'age': 7.0, 'p3': 14.72, 'p50': 16.07, 'p97': 20.16},
    {'age': 9.0, 'p3': 14.90, 'p50': 16.58, 'p97': 21.82},
  ];

  // 女童 BMI 參考數據 (依據您的 ODS 檔案計算結果)
  static const List<Map<String, dynamic>> girlBmiReference = [
    {'age': 0.0, 'p3': 11.54, 'p50': 13.27, 'p97': 15.12},
    {'age': 0.5, 'p3': 15.33, 'p50': 16.91, 'p97': 18.78},
    {'age': 1.0, 'p3': 14.83, 'p50': 16.25, 'p97': 18.15},
    {'age': 2.0, 'p3': 14.27, 'p50': 15.41, 'p97': 17.06},
    {'age': 3.0, 'p3': 14.24, 'p50': 15.37, 'p97': 17.04},
    {'age': 5.0, 'p3': 13.86, 'p50': 15.21, 'p97': 17.41},
  ];

  // 輔助函式：根據性別獲取數據
  static List<Map<String, dynamic>> getReference(String gender) {
    return gender == 'boy' ? boyBmiReference : girlBmiReference;
  }
}