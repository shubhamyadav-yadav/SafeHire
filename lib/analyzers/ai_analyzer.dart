import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AIAnalyzer {
  static bool _modelLoaded = false;

  static String get _geminiApiKey => dotenv.env['GEMINI_API_KEY_1'] ?? '';

  // Using gemini-1.5-flash — fast, accurate, free tier available
  static const String _model = "gemini-1.5-flash";

  static Future<void> loadModel() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _modelLoaded = true;
    print("Gemini AI Ready");
  }

  static bool isLoaded() => _modelLoaded;

  // ─── Main Gemini API call ─────────────────────────────────────────
  static Future<String?> askClaude(String systemPrompt, String userContent) async {
    // NOTE: Parameter kept as "askClaude" for backward compatibility
    // with email_analyzer.dart and job_analyzer.dart
    return await askGemini(systemPrompt, userContent);
  }

  static Future<String?> askGemini(String systemPrompt, String userContent) async {
    try {
      final url = Uri.parse(
        "https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_geminiApiKey",
      );

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "system_instruction": {
            "parts": [{"text": systemPrompt}]
          },
          "contents": [
            {
              "parts": [{"text": userContent}],
              "role": "user"
            }
          ],
          "generationConfig": {
            "temperature": 0.1,       // low temp = more accurate/consistent
            "maxOutputTokens": 300,
            "topP": 0.8,
          },
          "safetySettings": [
            {"category": "HARM_CATEGORY_HARASSMENT",        "threshold": "BLOCK_NONE"},
            {"category": "HARM_CATEGORY_HATE_SPEECH",       "threshold": "BLOCK_NONE"},
            {"category": "HARM_CATEGORY_SEXUALLY_EXPLICIT", "threshold": "BLOCK_NONE"},
            {"category": "HARM_CATEGORY_DANGEROUS_CONTENT", "threshold": "BLOCK_NONE"},
          ],
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Extract text from Gemini response structure
        final candidates = data["candidates"] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]["content"];
          final parts   = content["parts"] as List?;
          if (parts != null && parts.isNotEmpty) {
            return parts[0]["text"] as String?;
          }
        }
        return null;

      } else if (response.statusCode == 400) {
        print("Gemini 400 Error: ${response.body}");
        return null;
      } else if (response.statusCode == 403) {
        print("Gemini API key invalid or quota exceeded");
        return null;
      } else {
        print("Gemini Error ${response.statusCode}: ${response.body}");
        return null;
      }
    } catch (e) {
      print("Gemini API error: $e");
      return null;
    }
  }
}