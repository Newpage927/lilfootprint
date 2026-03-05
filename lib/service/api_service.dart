import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // 你的 ngrok 網址 (注意：ngrok 免費版每次重開網址都會變，要記得更新)
  static const String baseUrl = 'https://epiboly-roentgenopaque-enid.ngrok-free.dev';

  // 取得首頁推薦資料
  // ageInYears: 寶寶目前的年齡 (例如 5.5)
  static Future<Map<String, dynamic>> fetchRecommendations(double ageInYears) async {
    // 假設後端路徑是 /api/recommendations，並帶上 age 參數
    final uri = Uri.parse('$baseUrl/api/recommend?age=$ageInYears');
    
    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        // 成功拿到資料，解碼 JSON
        // 為了防止中文亂碼，使用 utf8.decode
        return json.decode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception('載入失敗: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('連線錯誤: $e');
    }
  }
  // 在 ApiService 類別裡加入這個函式
  static Future<double?> fetchLocalTemperature(double lat, double lon) async {
    try {
      // Open-Meteo 免費氣象 API
      final url = 'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // 取得現在氣溫
        return data['current_weather']['temperature']?.toDouble();
      }
    } catch (e) {
      print('Weather API Error: $e');
    }
    return null; // 失敗回傳 null
  }
  static Future<Map<String, dynamic>> fetchAlerts() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/alerts'));

      if (response.statusCode == 200) {
        final decoded = json.decode(utf8.decode(response.bodyBytes));
        
        // 直接回傳整個 decoded 物件，這樣外面可以拿到 status_summary 和 data
        if (decoded is Map<String, dynamic>) {
           return decoded;
        } else {
           return {};
        }
      } else {
        print('Alerts API Error: ${response.statusCode}');
        return {};
      }
    } catch (e) {
      print('Fetch Alerts Error: $e');
      return {};
    }
  }
  static Future<List<dynamic>> fetchGrowthAnalysis(String trend) async {
    final uri = Uri.parse('$baseUrl/api/growth_analysis?trend=$trend');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes));
    }
    return [];
  }
}