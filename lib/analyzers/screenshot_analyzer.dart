import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ScreenshotAnalyzer {
  static String get _geminiApiKey => dotenv.env['GEMINI_API_KEY_2'] ?? '';

  // ✅ Correct working model names (try in order)
  static const List<String> _models = [
    "gemini-1.5-flash",
    "gemini-1.5-flash-latest",
    "gemini-pro-vision",
  ];

  static Future<Map<String, dynamic>> analyze(File imageFile) async {
    try {
      final bytes       = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      final ext         = imageFile.path.split('.').last.toLowerCase();
      final mimeType    = (ext == 'png') ? 'image/png' : 'image/jpeg';

      // Try each model until one works
      for (final model in _models) {
        final result = await _tryModel(model, base64Image, mimeType);
        if (result != null) return result;
      }

      return _error("All models failed. Check your API key.");
    } catch (e) {
      return _error("Error: $e");
    }
  }

  static Future<Map<String, dynamic>?> _tryModel(
      String model, String base64Image, String mimeType) async {
    try {
      final url = Uri.parse(
        "https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$_geminiApiKey",
      );

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "contents": [
            {
              "role": "user",
              "parts": [
                {
                  "text": """You are an expert scam and fraud detection AI.
Analyze this screenshot carefully. It may contain an email, SMS, WhatsApp message, job offer, URL, or any other content.

Respond ONLY in this exact JSON format, nothing else:
{
  "verdict": "safe" | "suspicious" | "danger",
  "score": <0-100 risk score>,
  "type": "<content type: Email / SMS / WhatsApp / Job Offer / URL / Other>",
  "reason": "<2-3 sentences explaining verdict>",
  "red_flags": ["<flag1>", "<flag2>", "<flag3>"]
}

Scoring rules:
- 0-25: Safe and legitimate
- 26-50: Slightly suspicious
- 51-75: Likely scam
- 76-100: Definite scam/phishing/fraud

Output valid JSON only, nothing else."""
                },
                {
                  "inline_data": {
                    "mime_type": mimeType,
                    "data": base64Image,
                  }
                }
              ]
            }
          ],
          "generationConfig": {
            "temperature": 0.1,
            "maxOutputTokens": 400,
          },
          "safetySettings": [
            {"category": "HARM_CATEGORY_HARASSMENT",        "threshold": "BLOCK_NONE"},
            {"category": "HARM_CATEGORY_HATE_SPEECH",       "threshold": "BLOCK_NONE"},
            {"category": "HARM_CATEGORY_SEXUALLY_EXPLICIT", "threshold": "BLOCK_NONE"},
            {"category": "HARM_CATEGORY_DANGEROUS_CONTENT", "threshold": "BLOCK_NONE"},
          ],
        }),
      ).timeout(const Duration(seconds: 20));

      print("Gemini [$model] status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data       = jsonDecode(response.body);
        final candidates = data["candidates"] as List?;

        if (candidates != null && candidates.isNotEmpty) {
          final text    = candidates[0]["content"]["parts"][0]["text"] as String;
          final cleaned = text.replaceAll("```json", "").replaceAll("```", "").trim();

          try {
            final parsed   = jsonDecode(cleaned);
            final verdict  = parsed["verdict"]    as String? ?? "suspicious";
            final score    = (parsed["score"]     as num?)?.toInt() ?? 50;
            final type     = parsed["type"]       as String? ?? "Unknown";
            final reason   = parsed["reason"]     as String? ?? "";
            final redFlags = (parsed["red_flags"] as List?)
                ?.map((e) => e.toString()).toList() ?? [];

            return {
              "verdict":   verdict,
              "score":     score,
              "type":      type,
              "reason":    reason,
              "red_flags": redFlags,
              "success":   true,
              "model":     model,
            };
          } catch (_) {
            // JSON parse failed but got response
            return {
              "verdict":   "suspicious",
              "score":     50,
              "type":      "Unknown",
              "reason":    text,
              "red_flags": [],
              "success":   true,
              "model":     model,
            };
          }
        }
      } else if (response.statusCode == 404) {
        print("Model $model not found, trying next...");
        return null; // try next model
      } else if (response.statusCode == 403) {
        return _error("Invalid API key. Check your Gemini API key.");
      } else if (response.statusCode == 429) {
        return _error("Rate limit exceeded. Wait a moment and try again.");
      } else {
        print("Model $model error ${response.statusCode}: ${response.body}");
        return null;
      }
    } catch (e) {
      print("Model $model exception: $e");
      return null;
    }
    return null;
  }

  static Map<String, dynamic> _error(String msg) => {
    "verdict":   "info",
    "score":     0,
    "type":      "Error",
    "reason":    msg,
    "red_flags": [],
    "success":   false,
  };
}