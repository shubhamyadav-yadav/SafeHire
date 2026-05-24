import 'package:shared_preferences/shared_preferences.dart';

class StatsService {
  static Future<void> incrementScan(bool isThreat) async {
    final prefs = await SharedPreferences.getInstance();

    int scans = prefs.getInt("scans") ?? 0;
    int threats = prefs.getInt("threats") ?? 0;

    scans++;

    if (isThreat) threats++;

    await prefs.setInt("scans", scans);
    await prefs.setInt("threats", threats);
  }

  static Future<Map<String, int>> getStats() async {
    final prefs = await SharedPreferences.getInstance();

    int scans = prefs.getInt("scans") ?? 0;
    int threats = prefs.getInt("threats") ?? 0;

    return {
      "scans": scans,
      "threats": threats,
      "safe": scans - threats,
    };
  }
}