import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final client = Supabase.instance.client;

  static Future<void> saveScore({
    required int score,
    required double accuracy,
    required double wpm,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) return;

    final existing =
        await client.from('profiles').select().eq('id', user.id).single();

    if (score > (existing['highscore'] ?? 0)) {
      await client.from('profiles').update({
        'highscore': score,
        'accuracy': accuracy,
        'wpm': wpm,
      }).eq('id', user.id);
    }
  }

  static Future<Map<String, dynamic>?> getProfile() async {
    final user = client.auth.currentUser;
    if (user == null) return null;

    return await client.from('profiles').select().eq('id', user.id).single();
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }
}
