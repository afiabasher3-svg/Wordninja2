import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/word_note.dart';

class SupabaseService {
  static final client = Supabase.instance.client;

  static Future<void> saveScore({
    required int score,
    required double accuracy,
    required double wpm,
    required int timePlayed, // seconds
  }) async {
    final user = client.auth.currentUser;
    if (user == null) return;

    // প্রতিটা session আলাদা row হিসেবে save হবে (History + Graph screen এইটা থেকেই ডেটা নেবে)
    await client.from('game_sessions').insert({
      'user_id': user.id,
      'wpm': wpm,
      'accuracy': accuracy,
      'time_played': timePlayed,
    });

    // Highscore হলে profile update হবে (আগের logic অপরিবর্তিত)
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

  static Future<List<Map<String, dynamic>>> fetchSessionHistory() async {
    final user = client.auth.currentUser;
    if (user == null) return [];
    final data = await client
        .from('game_sessions')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<Map<String, dynamic>?> getProfile() async {
    final user = client.auth.currentUser;
    if (user == null) return null;
    return await client.from('profiles').select().eq('id', user.id).single();
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  // =====================================================================
  // Vocabulary Notebook (word_notes)
  // =====================================================================

  static Future<void> saveSessionWords(List<WordNote> sessionWords) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null || sessionWords.isEmpty) return;

    final rows = sessionWords.map((w) => w.toUpsertMap(userId)).toList();

    await client.from('word_notes').upsert(
          rows,
          onConflict: 'user_id,word,topic_id,mode',
        );
  }

  static Future<List<WordNote>> fetchWordNotes({
    String? statusFilter,
    bool? learnedFilter,
  }) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];

    var query = client.from('word_notes').select().eq('user_id', userId);

    if (statusFilter != null) {
      query = query.eq('status', statusFilter);
    }
    if (learnedFilter != null) {
      query = query.eq('learned', learnedFilter);
    }

    final response = await query.order('created_at', ascending: false);

    return (response as List)
        .map((row) => WordNote.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  static Future<List<WordNote>> fetchReviewWords() {
    return fetchWordNotes(learnedFilter: false);
  }

  static Future<void> markWordLearned(String wordNoteId, bool learned) async {
    await client
        .from('word_notes')
        .update({'learned': learned}).eq('id', wordNoteId);
  }
}
