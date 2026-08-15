// lib/models/word_note.dart
//
// Represents one row of the `word_notes` table / one vocabulary entry.
// Does not touch or rename anything in models/word_tile.dart.

class WordNote {
  final String? id; // null until saved to Supabase
  final String word;
  final String meaning;
  final String pronunciation;
  final String exampleSentence;
  final int topicId;
  final String mode; // 'easy' | 'advanced'
  final String status; // 'popped' | 'missed' | 'synonym'
  final bool learned;
  final DateTime? createdAt;

  const WordNote({
    this.id,
    required this.word,
    required this.meaning,
    required this.pronunciation,
    this.exampleSentence = '',
    required this.topicId,
    required this.mode,
    required this.status,
    this.learned = false,
    this.createdAt,
  });

  /// Unique key used for de-duplication *within a single session*
  /// (Part 3: "Do not duplicate words unnecessarily").
  String get sessionKey => '${word.toLowerCase()}_${topicId}_$mode';

  factory WordNote.fromMap(Map<String, dynamic> map) {
    return WordNote(
      id: map['id'] as String?,
      word: (map['word'] ?? '') as String,
      meaning: (map['meaning'] ?? '') as String,
      pronunciation: (map['pronunciation'] ?? '') as String,
      exampleSentence: (map['example_sentence'] ?? '') as String,
      topicId: map['topic_id'] is int
          ? map['topic_id'] as int
          : int.tryParse('${map['topic_id']}') ?? 0,
      mode: (map['mode'] ?? 'easy') as String,
      status: (map['status'] ?? 'popped') as String,
      learned: (map['learned'] ?? false) as bool,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }

  /// Used when upserting a session's words into Supabase.
  Map<String, dynamic> toUpsertMap(String userId) {
    return {
      'user_id': userId,
      'word': word,
      'meaning': meaning,
      'pronunciation': pronunciation,
      'example_sentence': exampleSentence,
      'topic_id': topicId,
      'mode': mode,
      'status': status,
      'learned': learned,
    };
  }

  WordNote copyWith({
    String? id,
    bool? learned,
    String? status,
    DateTime? createdAt,
    String? exampleSentence,
  }) {
    return WordNote(
      id: id ?? this.id,
      word: word,
      meaning: meaning,
      pronunciation: pronunciation,
      exampleSentence: exampleSentence ?? this.exampleSentence,
      topicId: topicId,
      mode: mode,
      status: status ?? this.status,
      learned: learned ?? this.learned,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
