import '../analyzers/ai_analyzer.dart';

class EmailAnalyzer {
  // ─── Claude AI Analysis ───────────────────────────────────────────
  static Future<Map<String, dynamic>> checkDetailed(String text) async {
    if (text.trim().isEmpty) {
      return _result("Please paste the email content", "none", 0);
    }

    // ── 1. Try Claude AI first ────────────────────────────────────
    try {
      final aiResponse = await AIAnalyzer.askClaude(
        """You are an expert email security analyst specializing in phishing and scam detection.
Analyze the email content and respond ONLY in this exact JSON format:
{
  "verdict": "safe" | "suspicious" | "danger",
  "score": <0-100 risk score>,
  "reason": "<one clear sentence explaining the verdict>",
  "flags": ["<flag1>", "<flag2>"]
}
Rules:
- "danger" if: phishing, credential harvesting, malware links, advance fee fraud, lottery scam, fake KYC
- "suspicious" if: unusual urgency, unverified sender claims, too-good-to-be-true offers
- "safe" if: normal communication with no red flags
Be strict and accurate. Only output valid JSON, nothing else.""",
        "Analyze this email:\n\n$text",
      );

      if (aiResponse != null) {
        // Clean and parse JSON
        final cleaned = aiResponse
            .replaceAll("```json", "")
            .replaceAll("```", "")
            .trim();

        try {
          // Simple JSON parsing without dart:convert for safety
          final verdict = _extractJson(cleaned, "verdict") ?? "suspicious";
          final scoreStr = _extractJson(cleaned, "score") ?? "50";
          final reason = _extractJson(cleaned, "reason") ?? "AI analysis complete";
          final score = int.tryParse(scoreStr.replaceAll(RegExp(r'[^0-9]'), '')) ?? 50;

          return _result(
            "$reason\n(AI Risk Score: $score/100)",
            verdict,
            score,
          );
        } catch (_) {
          // JSON parse failed, fall through to rules
        }
      }
    } catch (e) {
      print("AI analysis failed, using rules: $e");
    }

    // ── 2. Rule-based fallback ────────────────────────────────────
    return _ruleBased(text);
  }

  // ─── Rule-based engine ────────────────────────────────────────────
  static Map<String, dynamic> _ruleBased(String text) {
    final lower = text.toLowerCase();
    int score = 0;
    List<String> flags = [];

    // High-risk phrases (+25 each)
    final highRisk = [
      "verify your account", "your account has been suspended",
      "click here to confirm", "update your payment",
      "won a prize", "lottery winner", "claim your reward",
      "nigerian prince", "advance fee", "wire transfer urgently",
      "send your bank details", "otp verification required",
      "your account will be closed", "immediate action required",
      "you have been selected", "congratulations you won",
      "free gift card", "act now before", "limited time offer",
      "dear customer", "dear user", "dear account holder",
    ];

    // Medium-risk phrases (+12 each)
    final medRisk = [
      "urgent", "immediately", "expire", "suspended", "locked",
      "verify", "confirm your", "click here", "login to your",
      "bank account", "credit card", "password", "pin number",
      "social security", "aadhar", "pan card", "kyc update",
      "investment opportunity", "work from home", "easy money",
    ];

    // Fake domain patterns
    final fakeDomains = [
      "paypa1", "g00gle", "amaz0n", "faceb00k", "micros0ft",
      ".xyz", ".top", ".click", "secure-login", "account-verify",
    ];

    for (final phrase in highRisk) {
      if (lower.contains(phrase)) {
        score += 25;
        flags.add(phrase);
        if (flags.length >= 3) break;
      }
    }

    for (final phrase in medRisk) {
      if (lower.contains(phrase)) {
        score += 12;
      }
    }

    for (final domain in fakeDomains) {
      if (lower.contains(domain)) {
        score += 30;
        flags.add("Suspicious domain: $domain");
      }
    }

    // Excessive caps (SHOUTING = scam indicator)
    final capsWords = RegExp(r'\b[A-Z]{4,}\b').allMatches(text).length;
    if (capsWords > 5) {
      score += 15;
      flags.add("Excessive capitalization");
    }

    // Multiple exclamation marks
    if ("!!!".allMatches(text).isNotEmpty || text.split("!").length > 5) {
      score += 10;
    }

    score = score.clamp(0, 100);

    if (score >= 50) {
      return _result(
        "High Risk Phishing Email\n${flags.isNotEmpty ? flags.first : 'Multiple scam indicators detected'}\n(Risk Score: $score/100)",
        "danger", score,
      );
    } else if (score >= 20) {
      return _result(
        "Suspicious Email — Proceed with caution\n${flags.isNotEmpty ? flags.first : 'Some red flags detected'}\n(Risk Score: $score/100)",
        "warning", score,
      );
    } else {
      return _result("Email appears safe\n(Risk Score: $score/100)", "safe", score);
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────
  static String? _extractJson(String json, String key) {
    final regex = RegExp('"$key"\\s*:\\s*"?([^",}\\]]+)"?');
    final match = regex.firstMatch(json);
    return match?.group(1)?.trim();
  }

  static Map<String, dynamic> _result(String message, String level, int score) {
    return {"message": message, "level": level, "score": score};
  }

  // Backward-compat wrapper
  static Future<String> check(String text) async {
    final r = await checkDetailed(text);
    return r["message"] as String;
  }
}