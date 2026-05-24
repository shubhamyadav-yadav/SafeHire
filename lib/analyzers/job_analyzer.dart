import '../analyzers/ai_analyzer.dart';

class JobAnalyzer {
  // ─── Claude AI Analysis ───────────────────────────────────────────
  static Future<Map<String, dynamic>> checkDetailed(String text) async {
    if (text.trim().isEmpty) {
      return _result("Please paste the job posting", "none", 0);
    }

    // ── 1. Try Claude AI first ────────────────────────────────────
    try {
      final aiResponse = await AIAnalyzer.askClaude(
        """You are an expert HR fraud analyst specializing in fake job offer detection.
Analyze the job posting and respond ONLY in this exact JSON format:
{
  "verdict": "safe" | "suspicious" | "danger",
  "score": <0-100 risk score>,
  "reason": "<one clear sentence explaining the verdict>",
  "flags": ["<flag1>", "<flag2>"]
}
Rules for "danger": requires registration fee, asks for bank/card details upfront, unrealistic salary 
  (e.g. 50k/month for simple work), no company name, work from home with huge pay, MLM/pyramid scheme
Rules for "suspicious": vague job description, no experience required for high pay, 
  immediate joining, too-good-to-be-true perks
Rules for "safe": real company name, realistic salary, clear responsibilities, proper contact info
Only output valid JSON, nothing else.""",
        "Analyze this job posting:\n\n$text",
      );

      if (aiResponse != null) {
        final cleaned = aiResponse
            .replaceAll("```json", "")
            .replaceAll("```", "")
            .trim();

        try {
          final verdict = _extractJson(cleaned, "verdict") ?? "suspicious";
          final scoreStr = _extractJson(cleaned, "score") ?? "50";
          final reason = _extractJson(cleaned, "reason") ?? "AI analysis complete";
          final score = int.tryParse(scoreStr.replaceAll(RegExp(r'[^0-9]'), '')) ?? 50;

          return _result(
            "$reason\n(AI Risk Score: $score/100)",
            verdict,
            score,
          );
        } catch (_) {}
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

    // 🚨 High risk — instant red flags (+35)
    final highRisk = [
      "registration fee", "pay to join", "security deposit",
      "send money", "wire transfer", "pay registration",
      "processing fee", "training fee", "joining fee",
      "provide your bank account", "share your card details",
      "100% work from home", "earn lakhs per month",
      "no experience no interview", "earn 50000 weekly",
      "mlm", "multi level marketing", "pyramid",
      "refer and earn unlimited", "binary income",
    ];

    // ⚠️ Medium risk (+18)
    final medRisk = [
      "earn money fast", "easy money", "no experience needed",
      "urgent hiring", "immediate joiners", "work from home",
      "part time earn", "data entry work", "typing work",
      "unlimited earning", "passive income", "be your own boss",
      "no qualification required", "anyone can apply",
      "₹50000", "50,000 per month", "1 lakh per month",
      "earn daily", "daily payout", "weekly salary",
      "no interview required", "direct joining",
      "guaranteed income", "100% placement",
    ];

    // ✅ Legitimacy signals (reduce score)
    final legit = [
      "company registration", "gst number", "linkedin",
      "glassdoor", "naukri.com", "indeed.com",
      "hr@", "careers@", "jobs@", "recruitment@",
      "probation period", "notice period", "pf", "esi",
      "annual ctc", "lpa", "fixed salary",
    ];

    for (final phrase in highRisk) {
      if (lower.contains(phrase)) {
        score += 35;
        flags.add(phrase);
        if (flags.length >= 3) break;
      }
    }

    for (final phrase in medRisk) {
      if (lower.contains(phrase)) score += 18;
    }

    // Legitimacy reduces score
    int legitCount = 0;
    for (final signal in legit) {
      if (lower.contains(signal)) legitCount++;
    }
    score -= legitCount * 10;

    // No company name mentioned
    if (!lower.contains("pvt") && !lower.contains("ltd") &&
        !lower.contains("inc") && !lower.contains("llp") &&
        !lower.contains("company") && !lower.contains("solutions") &&
        !lower.contains("technologies")) {
      score += 15;
      flags.add("No company name mentioned");
    }

    // No contact email
    if (!RegExp(r'[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}').hasMatch(text)) {
      score += 10;
    }

    // Unrealistic salary detection
    final salaryMatch = RegExp(r'(\d+)\s*(k|,000|lakh|lac)\s*(per|a)?\s*(day|week|month)?').firstMatch(lower);
    if (salaryMatch != null) {
      final rawNum = int.tryParse(salaryMatch.group(1) ?? '0') ?? 0;
      final unit = salaryMatch.group(2) ?? '';
      final period = salaryMatch.group(4) ?? 'month';
      final monthly = unit.contains('lakh') || unit.contains('lac')
          ? rawNum * 100000
          : unit == 'k' ? rawNum * 1000 : rawNum * 1000;
      // Flag if > ₹5L/month for non-senior roles
      if (period == 'month' && monthly > 500000) {
        score += 25;
        flags.add("Unrealistically high salary claim");
      }
    }

    score = score.clamp(0, 100);

    if (score >= 50) {
      return _result(
        "Likely Fake Job — ${flags.isNotEmpty ? flags.first : 'Multiple fraud indicators'}\n(Risk Score: $score/100)",
        "danger", score,
      );
    } else if (score >= 20) {
      return _result(
        "Suspicious Job Posting — Verify before applying\n${flags.isNotEmpty ? flags.first : 'Some red flags detected'}\n(Risk Score: $score/100)",
        "warning", score,
      );
    } else {
      return _result("Job posting appears legitimate\n(Risk Score: $score/100)", "safe", score);
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
  static String check(String text) {
    // sync wrapper — use checkDetailed() for full results
    final lower = text.toLowerCase();
    if (lower.contains("registration fee") ||
        lower.contains("earn money fast") ||
        lower.contains("no experience needed") ||
        lower.contains("pay to join")) {
      return "⚠️ Scam Likely";
    }
    return "✅ Safe Job";
  }
}