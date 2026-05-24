import '../services/safe_browsing_service.dart';

class URLChecker {
  // ─── Known safe domains (whitelist) ──────────────────────────────
  static const List<String> _safeDomains = [
    "google.com", "youtube.com", "facebook.com", "instagram.com",
    "twitter.com", "x.com", "linkedin.com", "github.com",
    "microsoft.com", "apple.com", "amazon.com", "wikipedia.org",
    "stackoverflow.com", "reddit.com", "netflix.com", "spotify.com",
    "whatsapp.com", "telegram.org", "zoom.us", "slack.com",
    "dropbox.com", "drive.google.com", "docs.google.com",
  ];

  // ─── High-risk TLDs ───────────────────────────────────────────────
  static const List<String> _riskyTlds = [
    ".xyz", ".top", ".click", ".loan", ".gq", ".ml", ".cf", ".tk",
    ".pw", ".work", ".zip", ".review", ".country", ".kim", ".cricket",
    ".science", ".party", ".faith", ".racing", ".win", ".bid",
  ];

  // ─── Suspicious keywords in URL ──────────────────────────────────
  static const List<String> _suspiciousKeywords = [
    "login", "signin", "verify", "account", "update", "secure",
    "banking", "paypal", "paytm", "bank", "password", "credential",
    "confirm", "wallet", "prize", "winner", "free-gift", "lucky",
    "claim", "reward", "bonus", "lucky-draw", "kyc", "otp",
  ];

  // ─── URL shorteners (hide real destination) ───────────────────────
  static const List<String> _shorteners = [
    "bit.ly", "tinyurl.com", "goo.gl", "t.co", "ow.ly",
    "is.gd", "buff.ly", "adf.ly", "bc.vc", "cutt.ly",
    "rb.gy", "shorturl.at", "tiny.cc",
  ];

  static Future<Map<String, dynamic>> checkDetailed(String url) async {
    try {
      url = url.trim();
      if (url.isEmpty) {
        return _result("Please enter a URL", "none", 0);
      }

      // Fix protocol
      if (!url.startsWith("http://") && !url.startsWith("https://")) {
        url = "https://$url";
      }

      Uri? uri;
      try {
        uri = Uri.parse(url);
      } catch (_) {
        return _result("Invalid URL format", "danger", 95);
      }

      final host = uri.host.toLowerCase().replaceAll("www.", "");

      // ── 1. Whitelist check ────────────────────────────────────────
      for (final safe in _safeDomains) {
        if (host == safe || host.endsWith(".$safe")) {
          return _result("Trusted domain — Safe", "safe", 2);
        }
      }

      // ── 2. Google Safe Browsing API ───────────────────────────────
      try {
        final isDanger = await SafeBrowsingService.checkUrl(url);
        if (isDanger) {
          return _result(
            "Flagged by Google Safe Browsing\nThis URL is known malware/phishing",
            "danger", 98,
          );
        }
      } catch (e) {
        print("Safe Browsing API failed, using rules: $e");
      }

      // ── 3. Rule-based scoring ─────────────────────────────────────
      int score = 0;
      List<String> reasons = [];

      // HTTP (not HTTPS)
      if (url.startsWith("http://")) {
        score += 20;
        reasons.add("Not using HTTPS");
      }

      // IP address instead of domain
      final ipRegex = RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$');
      if (ipRegex.hasMatch(host)) {
        score += 40;
        reasons.add("Uses IP address instead of domain");
      }

      // URL shortener
      for (final shortener in _shorteners) {
        if (host == shortener || host.endsWith(".$shortener")) {
          score += 25;
          reasons.add("URL shortener hides real destination");
          break;
        }
      }

      // Risky TLD
      for (final tld in _riskyTlds) {
        if (host.endsWith(tld)) {
          score += 30;
          reasons.add("High-risk domain extension ($tld)");
          break;
        }
      }

      // Suspicious keywords
      final fullUrl = url.toLowerCase();
      int kwCount = 0;
      for (final kw in _suspiciousKeywords) {
        if (fullUrl.contains(kw)) kwCount++;
      }
      if (kwCount >= 3) {
        score += 35;
        reasons.add("Multiple phishing keywords detected");
      } else if (kwCount >= 1) {
        score += 15;
        reasons.add("Suspicious keywords in URL");
      }

      // @ symbol in URL (classic phishing trick)
      if (url.contains("@")) {
        score += 40;
        reasons.add("@ symbol used (phishing trick)");
      }

      // Typosquatting check (common brands misspelled)
      final typosquats = {
        "paypa1": "paypal", "g00gle": "google", "arnazon": "amazon",
        "faceb00k": "facebook", "micros0ft": "microsoft",
        "linkedln": "linkedin", "paytm-secure": "paytm",
      };
      for (final fake in typosquats.keys) {
        if (host.contains(fake)) {
          score += 50;
          reasons.add("Typosquatting detected (fake ${typosquats[fake]})");
        }
      }

      // Too many subdomains
      final parts = host.split(".");
      if (parts.length > 4) {
        score += 20;
        reasons.add("Suspicious subdomain structure");
      }

      // Excessively long URL
      if (url.length > 150) {
        score += 15;
        reasons.add("Unusually long URL");
      }

      // ── 4. Final verdict ──────────────────────────────────────────
      score = score.clamp(0, 100);

      if (score >= 60) {
        return _result(
          "High Risk — ${reasons.first}\n(${reasons.length} issue${reasons.length > 1 ? 's' : ''} found)",
          "danger", score,
        );
      } else if (score >= 25) {
        return _result(
          "Suspicious URL — ${reasons.isNotEmpty ? reasons.first : 'Proceed with caution'}\n(Risk score: $score/100)",
          "warning", score,
        );
      } else {
        return _result("URL appears safe\n(Risk score: $score/100)", "safe", score);
      }
    } catch (e) {
      return _result("Error analyzing URL: $e", "danger", 50);
    }
  }

  static Map<String, dynamic> _result(String message, String level, int score) {
    return {"message": message, "level": level, "score": score};
  }

  // Backward-compat wrapper
  static Future<String> check(String url) async {
    final r = await checkDetailed(url);
    return r["message"] as String;
  }
}