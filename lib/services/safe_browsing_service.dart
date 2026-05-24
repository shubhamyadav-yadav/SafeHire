import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class SafeBrowsingService {
  static String get _apiKey => dotenv.env['GOOGLE_SAFE_BROWSING_KEY'] ?? '';

  static Future<bool> checkUrl(String url) async {
    try {
      final response = await http.post(
        Uri.parse(
          "https://safebrowsing.googleapis.com/v4/threatMatches:find?key=$_apiKey",
        ),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "client": {
            "clientId": "scamshield",
            "clientVersion": "1.0"
          },
          "threatInfo": {
            "threatTypes": ["MALWARE", "SOCIAL_ENGINEERING"],
            "platformTypes": ["ANY_PLATFORM"],
            "threatEntryTypes": ["URL"],
            "threatEntries": [
              {"url": url}
            ]
          }
        }),
      );

      // 🔍 Agar "matches" aaya → dangerous
      if (response.statusCode == 200 &&
          response.body.contains("matches")) {
        return true;
      }

      return false;
    } catch (e) {
      print("SafeBrowsing Error: $e");
      return false;
    }
  }
}