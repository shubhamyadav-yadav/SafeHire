import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class MLEngine {
  static const String modelName    = "ScamShield-NLP-v2.1";
  static const String modelBackend = "Gemini-1.5-Flash";
  static const String modelVersion = "2.1.0";
  static const int    inputMaxLen  = 512;

  static String get _geminiApiKey => dotenv.env['GEMINI_API_KEY_2'] ?? '';

  // ✅ Try models in order until one works
  static const List<String> _models = [
    "gemini-1.5-flash",
    "gemini-1.5-flash-latest",
    "gemini-1.0-pro",
  ];

  static bool _initialized = false;
  static int  _totalInferences = 0;

  static Future<void> initialize() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _initialized = true;
    print("[$modelName] Initialized. Backend: $modelBackend");
  }

  static bool get isInitialized    => _initialized;
  static int  get totalInferences  => _totalInferences;

  static Future<MLResult> classify({
    required String input,
    required MLTaskType task,
  }) async {
    if (!_initialized) await initialize();

    final processed = _preprocess(input);
    final stopwatch = Stopwatch()..start();

    for (final model in _models) {
      try {
        final raw = await _runInference(processed, task, model);
        if (raw != null) {
          stopwatch.stop();
          _totalInferences++;
          return _parseOutput(raw, stopwatch.elapsedMilliseconds);
        }
      } catch (e) {
        print("[$modelName] Model $model failed: $e");
      }
    }

    stopwatch.stop();
    return _ruleBasedFallback(input, task, stopwatch.elapsedMilliseconds);
  }

  static String _preprocess(String input) {
    var processed = input.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (processed.length > inputMaxLen * 4) {
      processed = processed.substring(0, inputMaxLen * 4);
    }
    return processed;
  }

  static Future<String?> _runInference(String input, MLTaskType task, String model) async {
    final url = Uri.parse(
      "https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$_geminiApiKey",
    );

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "system_instruction": {
          "parts": [{"text": _buildPrompt(task)}]
        },
        "contents": [
          {"role": "user", "parts": [{"text": input}]}
        ],
        "generationConfig": {
          "temperature": 0.05,
          "maxOutputTokens": 256,
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

    print("[$modelName] Model=$model Status=${response.statusCode}");

    if (response.statusCode == 200) {
      final data       = jsonDecode(response.body);
      final candidates = data["candidates"] as List?;
      if (candidates != null && candidates.isNotEmpty) {
        return candidates[0]["content"]["parts"][0]["text"] as String?;
      }
    } else if (response.statusCode == 404) {
      print("Model $model not found, trying next...");
      return null;
    } else if (response.statusCode == 403) {
      print("Invalid API key!");
      return null;
    }
    return null;
  }

  static String _buildPrompt(MLTaskType task) {
    switch (task) {
      case MLTaskType.urlClassification:
        return """You are a URL classification model trained on phishing and malware datasets.
Classify the input URL and respond ONLY in this JSON format:
{"label":"safe"|"suspicious"|"malicious","confidence":<0.0-1.0>,"reason":"<one sentence>","features":["<feature1>","<feature2>"]}
Output valid JSON only.""";

      case MLTaskType.emailClassification:
        return """You are an email spam/phishing classification model.
Classify the email and respond ONLY in this JSON format:
{"label":"legitimate"|"spam"|"phishing","confidence":<0.0-1.0>,"reason":"<one sentence>","features":["<feature1>","<feature2>"]}
Output valid JSON only.""";

      case MLTaskType.jobClassification:
        return """You are a fake job detection model trained on employment fraud datasets.
Classify the job posting and respond ONLY in this JSON format:
{"label":"legitimate"|"suspicious"|"fraudulent","confidence":<0.0-1.0>,"reason":"<one sentence>","features":["<feature1>","<feature2>"]}
Output valid JSON only.""";

      case MLTaskType.textClassification:
        return """You are a general scam/fraud text classification model.
Classify the text and respond ONLY in this JSON format:
{"label":"safe"|"suspicious"|"scam","confidence":<0.0-1.0>,"reason":"<one sentence>","features":["<feature1>","<feature2>"]}
Output valid JSON only.""";
    }
  }

  static MLResult _parseOutput(String raw, int inferenceMs) {
    try {
      final cleaned = raw.replaceAll("```json", "").replaceAll("```", "").trim();
      final json    = jsonDecode(cleaned);

      final label      = json["label"]       as String?  ?? "suspicious";
      final confidence = (json["confidence"] as num?)?.toDouble() ?? 0.5;
      final reason     = json["reason"]      as String?  ?? "";
      final features   = (json["features"]   as List?)
          ?.map((e) => e.toString()).toList() ?? [];

      final level = _labelToLevel(label);
      final score = _confidenceToScore(confidence, level);

      return MLResult(
        label: label, level: level, confidence: confidence,
        score: score, reason: reason, features: features,
        inferenceMs: inferenceMs, modelName: modelName, usedFallback: false,
      );
    } catch (_) {
      return _defaultResult(inferenceMs);
    }
  }

  static MLResult _ruleBasedFallback(String input, MLTaskType task, int inferenceMs) {
    final lower = input.toLowerCase();
    int score = 0;
    final redFlags = [
      "urgent", "verify", "click here", "prize", "winner", "lottery",
      "bank account", "password", "otp", "kyc", "registration fee",
      "earn money fast", "work from home", "no experience", "paypa1",
      "bit.ly", "tinyurl", ".xyz", "free gift",
    ];
    for (final flag in redFlags) {
      if (lower.contains(flag)) score += 15;
    }
    score = score.clamp(0, 95);
    final level      = score >= 60 ? "danger" : score >= 25 ? "warning" : "safe";
    final confidence = score / 100;

    return MLResult(
      label: level == "danger" ? "malicious" : level == "warning" ? "suspicious" : "legitimate",
      level: level, confidence: confidence, score: score,
      reason: "Rule-based classification (AI unavailable)",
      features: ["keyword_analysis", "pattern_matching"],
      inferenceMs: inferenceMs, modelName: "$modelName (fallback)", usedFallback: true,
    );
  }

  static String _labelToLevel(String label) {
    switch (label.toLowerCase()) {
      case "malicious": case "phishing": case "spam": case "fraudulent": case "scam":
      return "danger";
      case "suspicious":
        return "warning";
      default:
        return "safe";
    }
  }

  static int _confidenceToScore(double confidence, String level) {
    switch (level) {
      case "danger":  return (60 + (confidence * 40)).round().clamp(0, 100);
      case "warning": return (25 + (confidence * 35)).round().clamp(0, 100);
      default:        return (confidence * 25).round().clamp(0, 100);
    }
  }

  static MLResult _defaultResult(int inferenceMs) {
    return MLResult(
      label: "suspicious", level: "warning", confidence: 0.5,
      score: 50, reason: "Could not complete analysis",
      features: [], inferenceMs: inferenceMs,
      modelName: modelName, usedFallback: true,
    );
  }
}

enum MLTaskType { urlClassification, emailClassification, jobClassification, textClassification }

class MLResult {
  final String       label;
  final String       level;
  final double       confidence;
  final int          score;
  final String       reason;
  final List<String> features;
  final int          inferenceMs;
  final String       modelName;
  final bool         usedFallback;

  const MLResult({
    required this.label, required this.level, required this.confidence,
    required this.score, required this.reason, required this.features,
    required this.inferenceMs, required this.modelName, required this.usedFallback,
  });

  String get confidencePct  => "${(confidence * 100).round()}%";
  String get inferenceTime  => inferenceMs < 1000
      ? "${inferenceMs}ms" : "${(inferenceMs / 1000).toStringAsFixed(1)}s";

  Map<String, dynamic> toMap() => {
    "label": label, "level": level, "confidence": confidence,
    "score": score, "reason": reason, "features": features,
    "inferenceMs": inferenceMs, "modelName": modelName,
    "usedFallback": usedFallback, "message": reason,
  };
}