import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final _client = Supabase.instance.client;

  // ─── Auth ──────────────────────────────────────────────────────────
  static User? get currentUser => _client.auth.currentUser;
  static bool  get isLoggedIn  => currentUser != null;
  static String get userEmail  => currentUser?.email ?? "";

  static Future<AuthResponse> signUp(String email, String password) async {
    return await _client.auth.signUp(email: email, password: password);
  }

  static Future<AuthResponse> signIn(String email, String password) async {
    return await _client.auth.signInWithPassword(email: email, password: password);
  }

  static Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // ─── Scan History ──────────────────────────────────────────────────
  static Future<void> saveScan({
    required String scanType,
    required String inputContent,
    required String result,
    required String level,
    required int    score,
    required String reason,
  }) async {
    if (!isLoggedIn) return;
    try {
      await _client.from('scan_history').insert({
        'user_id':       currentUser!.id,
        'scan_type':     scanType,
        'input_content': inputContent.length > 500
            ? inputContent.substring(0, 500)
            : inputContent,
        'result':        result,
        'level':         level,
        'score':         score,
        'reason':        reason,
      });
    } catch (e) {
      print("Save scan error: $e");
    }
  }

  static Future<List<Map<String, dynamic>>> getHistory() async {
    if (!isLoggedIn) return [];
    try {
      final response = await _client
          .from('scan_history')
          .select()
          .eq('user_id', currentUser!.id)
          .order('created_at', ascending: false)
          .limit(50);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print("Get history error: $e");
      return [];
    }
  }

  static Future<void> deleteHistory() async {
    if (!isLoggedIn) return;
    try {
      await _client
          .from('scan_history')
          .delete()
          .eq('user_id', currentUser!.id);
    } catch (e) {
      print("Delete history error: $e");
    }
  }

  static Future<Map<String, int>> getCloudStats() async {
    if (!isLoggedIn) return {"scans": 0, "threats": 0, "safe": 0};
    try {
      final response = await _client
          .from('scan_history')
          .select('level')
          .eq('user_id', currentUser!.id);

      final list = List<Map<String, dynamic>>.from(response);
      final total   = list.length;
      final threats = list.where((e) => e['level'] == 'danger' || e['level'] == 'warning').length;
      return {"scans": total, "threats": threats, "safe": total - threats};
    } catch (e) {
      return {"scans": 0, "threats": 0, "safe": 0};
    }
  }
}