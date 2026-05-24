import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

class APKAnalyzer {
  // ─── Permission Risk Database ─────────────────────────────────────
  static const Map<String, int> _permissionRisk = {
    // 🚨 Critical (35 pts each)
    "android.permission.READ_SMS": 35,
    "android.permission.RECEIVE_SMS": 35,
    "android.permission.SEND_SMS": 35,
    "android.permission.READ_CALL_LOG": 35,
    "android.permission.PROCESS_OUTGOING_CALLS": 35,
    "android.permission.RECORD_AUDIO": 30,
    "android.permission.CAMERA": 25,
    "android.permission.READ_CONTACTS": 25,
    "android.permission.ACCESS_FINE_LOCATION": 25,
    "android.permission.ACCESS_COARSE_LOCATION": 20,
    "android.permission.READ_EXTERNAL_STORAGE": 20,
    "android.permission.WRITE_EXTERNAL_STORAGE": 20,
    "android.permission.GET_ACCOUNTS": 20,

    // ⚠️ High (20 pts each)
    "android.permission.USE_BIOMETRIC": 20,
    "android.permission.USE_FINGERPRINT": 20,
    "android.permission.BIND_ACCESSIBILITY_SERVICE": 35, // dangerous for banking trojans
    "android.permission.BIND_DEVICE_ADMIN": 35,
    "android.permission.REQUEST_INSTALL_PACKAGES": 30,
    "android.permission.SYSTEM_ALERT_WINDOW": 25, // overlay attacks
    "android.permission.DISABLE_KEYGUARD": 25,
    "android.permission.REBOOT": 30,
    "android.permission.MOUNT_UNMOUNT_FILESYSTEMS": 20,

    // ⚠️ Medium (10 pts each)
    "android.permission.INTERNET": 5,
    "android.permission.ACCESS_NETWORK_STATE": 3,
    "android.permission.ACCESS_WIFI_STATE": 3,
    "android.permission.RECEIVE_BOOT_COMPLETED": 10,
    "android.permission.FOREGROUND_SERVICE": 8,
    "android.permission.WAKE_LOCK": 5,
    "android.permission.VIBRATE": 2,
    "android.permission.FLASHLIGHT": 2,
  };

  static const Map<String, String> _permissionDescriptions = {
    "android.permission.READ_SMS": "Can read your SMS messages (OTP theft risk)",
    "android.permission.RECEIVE_SMS": "Can intercept incoming SMS",
    "android.permission.SEND_SMS": "Can send SMS on your behalf",
    "android.permission.RECORD_AUDIO": "Can use microphone to record audio",
    "android.permission.CAMERA": "Can access your camera",
    "android.permission.READ_CONTACTS": "Can access all your contacts",
    "android.permission.ACCESS_FINE_LOCATION": "Can track your exact GPS location",
    "android.permission.BIND_ACCESSIBILITY_SERVICE": "Can control your screen (banking trojan risk)",
    "android.permission.BIND_DEVICE_ADMIN": "Can control device settings",
    "android.permission.REQUEST_INSTALL_PACKAGES": "Can install other apps silently",
    "android.permission.SYSTEM_ALERT_WINDOW": "Can overlay on top of other apps (phishing risk)",
    "android.permission.GET_ACCOUNTS": "Can access your Google/email accounts",
    "android.permission.READ_CALL_LOG": "Can read your call history",
  };

  // ─── Main Analyze ────────────────────────────────────────────────
  static Future<Map<String, dynamic>> analyzeDetailed(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final hash = sha256.convert(bytes).toString();
      final fileSizeMB = (bytes.length / 1024 / 1024).toStringAsFixed(2);

      // Try to parse APK as ZIP
      List<String> foundPermissions = [];
      List<String> foundActivities = [];
      bool hasNativeLibs = false;
      bool hasDexFiles = false;
      int dexCount = 0;
      String packageName = "Unknown";

      try {
        final archive = ZipDecoder().decodeBytes(bytes);

        for (final entry in archive) {
          final name = entry.name.toLowerCase();

          // Count DEX files (multiple DEX = complex app)
          if (name.endsWith(".dex")) {
            hasDexFiles = true;
            dexCount++;
          }

          // Native libraries (can hide malicious code)
          if (name.contains("lib/") && name.endsWith(".so")) {
            hasNativeLibs = true;
          }

          // Parse AndroidManifest.xml (binary XML — extract readable strings)
          if (name == "androidmanifest.xml") {
            try {
              final content = entry.content as List<int>;
              final rawString = String.fromCharCodes(
                content.where((b) => b >= 32 && b < 127).toList(),
              );

              // Extract permissions from raw string
              final allPerms = _permissionRisk.keys;
              for (final perm in allPerms) {
                final shortPerm = perm.replaceAll("android.permission.", "");
                if (rawString.contains(shortPerm)) {
                  if (!foundPermissions.contains(perm)) {
                    foundPermissions.add(perm);
                  }
                }
              }

              // Try to extract package name
              final pkgMatch = RegExp(r'([a-z][a-z0-9_]*\.[a-z][a-z0-9_.]+)')
                  .firstMatch(rawString);
              if (pkgMatch != null) packageName = pkgMatch.group(0) ?? "Unknown";
            } catch (_) {}
          }
        }
      } catch (e) {
        // Not a valid ZIP/APK
        return {
          "message": "Invalid APK file — could not parse",
          "level": "danger",
          "score": 80,
          "details": "File does not appear to be a valid APK",
          "permissions": [],
          "hash": hash,
        };
      }

      // ── Score calculation ────────────────────────────────────────
      int score = 0;
      List<String> dangerousPerms = [];
      List<String> permDescriptions = [];

      for (final perm in foundPermissions) {
        final risk = _permissionRisk[perm] ?? 0;
        score += risk;
        if (risk >= 20) {
          dangerousPerms.add(perm.replaceAll("android.permission.", ""));
          if (_permissionDescriptions.containsKey(perm)) {
            permDescriptions.add(_permissionDescriptions[perm]!);
          }
        }
      }

      // Multiple DEX files = higher complexity risk
      if (dexCount > 2) {
        score += 15;
      }

      // Native libs without being a game/media app
      if (hasNativeLibs && !foundPermissions.any((p) => p.contains("CAMERA"))) {
        score += 10;
      }

      score = score.clamp(0, 100);

      // ── Build result ──────────────────────────────────────────────
      String level;
      String verdict;
      if (score >= 65) {
        level = "danger";
        verdict = "HIGH RISK APK — Likely Malware/Spyware";
      } else if (score >= 35) {
        level = "warning";
        verdict = "Suspicious APK — Review permissions carefully";
      } else {
        level = "safe";
        verdict = "APK appears safe — Low risk permissions";
      }

      final topDangers = permDescriptions.take(3).toList();
      final detailLines = [
        verdict,
        "",
        "📦 Package: $packageName",
        "📁 Size: ${fileSizeMB}MB",
        "🔐 SHA-256: ${hash.substring(0, 16)}...",
        "⚙️  DEX files: $dexCount",
        if (hasNativeLibs) "📚 Native libraries: Yes",
        "",
        "🔑 Dangerous permissions (${dangerousPerms.length}):",
        if (dangerousPerms.isEmpty) "  None detected",
        ...dangerousPerms.take(5).map((p) => "  • $p"),
        if (topDangers.isNotEmpty) "",
        if (topDangers.isNotEmpty) "⚠️ Risks:",
        ...topDangers.map((d) => "  • $d"),
        "",
        "Risk Score: $score/100",
      ];

      return {
        "message": detailLines.join("\n"),
        "level": level,
        "score": score,
        "permissions": foundPermissions,
        "hash": hash,
      };
    } catch (e) {
      return {
        "message": "Error analyzing APK: $e",
        "level": "danger",
        "score": 50,
        "permissions": [],
        "hash": "",
      };
    }
  }

  // Backward-compat wrapper
  static Future<String> analyze(File file) async {
    final r = await analyzeDetailed(file);
    return r["message"] as String;
  }
}