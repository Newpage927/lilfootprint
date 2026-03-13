import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://epiboly-roentgenopaque-enid.ngrok-free.dev';

  static Future<Map<String, dynamic>> fetchRecommendations(double ageInYears) async {
    final uri = Uri.parse('$baseUrl/api/recommend?age=$ageInYears');
    
    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception('載入失敗: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('連線錯誤: $e');
    }
  }

  static Future<double?> fetchLocalTemperature(double lat, double lon) async {
    try {
      final url = 'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['current_weather']['temperature']?.toDouble();
      }
    } catch (e) {
      print('Weather API Error: $e');
    }
    return null;
  }
  static Future<Map<String, dynamic>> fetchAlerts() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/alerts'));

      if (response.statusCode == 200) {
        final decoded = json.decode(utf8.decode(response.bodyBytes));
        
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
    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final decoded = json.decode(utf8.decode(response.bodyBytes));

        if (decoded is Map && decoded.containsKey('advice')) {
          return decoded['advice'] as List<dynamic>;
        } 
        else if (decoded is List) {
          return decoded;
        }
      }
    } catch (e) {
      print('Growth Analysis API Error: $e');
    }
    return [];
  }
}