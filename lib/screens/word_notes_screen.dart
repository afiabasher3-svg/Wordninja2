import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/word_note.dart';
import '../services/supabase_service.dart';
import 'result_screen.dart'
    show kBgDark, kBgCard, kPurplePrimary, kPurpleAccent, kPurpleLight;

class WordNotesScreen extends StatefulWidget {
  final int? initialTopicId;
  final String? initialMode;

  const WordNotesScreen({super.key, this.initialTopicId, this.initialMode});

  @override
  State<WordNotesScreen> createState() => _WordNotesScreenState();
}

class _WordNotesScreenState extends State<WordNotesScreen> {
  final FlutterTts _tts = FlutterTts();
  final TextEditingController _searchController = TextEditingController();

  List<WordNote> _allWords = [];
  bool _loading = true;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadWords();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.42);
    await _tts.setPitch(1.0);
  }

  Future<void> _loadWords() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) return;

      var query = SupabaseService.client
          .from('word_notes')
          .select()
          .eq('user_id', userId)
          .eq('saved', true);

      if (widget.initialTopicId != null) {
        query = query.eq('topic_id', widget.initialTopicId!);
      }
      if (widget.initialMode != null) {
        query = query.eq('mode', widget.initialMode!);
      }

      final response = await query.order('created_at', ascending: false);
      setState(() {
        _allWords = (response as List)
            .map((row) => WordNote.fromMap(row as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load notebook. Pull to refresh.';
        _loading = false;
      });
    }
  }

  Future<void> _speak(String text) async {
    if (text.isEmpty) return;
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> _removeFromNotebook(WordNote note) async {
    setState(() {
      _allWords.removeWhere((w) => w.id == note.id);
    });
    try {
      await SupabaseService.client
          .from('word_notes')
          .update({'saved': false})
          .eq('word', note.word)
          .eq('topic_id', note.topicId)
          .eq('mode', note.mode);
    } catch (_) {
      setState(() => _allWords.insert(0, note));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not remove. Try again.')),
        );
      }
    }
  }

  List<WordNote> get _filteredWords {
    if (_query.isEmpty) return _allWords;
    return _allWords
        .where((w) =>
            w.word.toLowerCase().contains(_query) ||
            w.meaning.toLowerCase().contains(_query) ||
            w.exampleSentence.toLowerCase().contains(_query))
        .toList();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'popped':
        return const Color(0xFF34D399);
      case 'missed':
        return const Color(0xFFF87171);
      case 'synonym':
        return const Color(0xFFFBBF24);
      default:
        return kPurpleLight;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'popped':
        return 'Popped ✅';
      case 'missed':
        return 'Missed ❌';
      case 'synonym':
        return 'Synonym ⭐';
      default:
        return status;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final words = _filteredWords;

    return Scaffold(
      backgroundColor: kBgDark,
      appBar: AppBar(
        backgroundColor: kBgDark,
        elevation: 0,
        title:
            const Text('📓 My Notebook', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search words, meanings, examples...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search, color: Colors.white38),
                  filled: true,
                  fillColor: kBgCard,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            if (!_loading && _error == null)
              Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${words.length} saved word${words.length == 1 ? '' : 's'}',
                    style:
                        const TextStyle(color: Color(0xFF8B8BAD), fontSize: 13),
                  ),
                ),
              ),

            Expanded(child: _buildBody(words)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(List<WordNote> words) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: kPurpleAccent));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            TextButton(
                onPressed: _loadWords,
                child:
                    const Text('Retry', style: TextStyle(color: kPurpleLight))),
          ],
        ),
      );
    }
    if (words.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('📖', style: TextStyle(fontSize: 48)),
              SizedBox(height: 16),
              Text(
                'No saved words yet.',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Tap the bookmark icon on word cards\nin the Result Screen to save words here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF8B8BAD), fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: kPurpleAccent,
      backgroundColor: kBgCard,
      onRefresh: _loadWords,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: words.length,
        itemBuilder: (context, index) => _wordCard(words[index]),
      ),
    );
  }

  Widget _wordCard(WordNote note) {
    final color = _statusColor(note.status);
    final hasExample = note.exampleSentence.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kBgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Word, pronunciation, status badge ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.word,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                      if (note.pronunciation.isNotEmpty)
                        Text(
                          '/${note.pronunciation}/',
                          style: const TextStyle(
                              color: kPurpleLight,
                              fontSize: 13,
                              fontStyle: FontStyle.italic),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withOpacity(0.4)),
                  ),
                  child: Text(
                    _statusLabel(note.status),
                    style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          // ── Meaning ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(
              note.meaning,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),

          // ── Example sentence ── (যদি থাকে)
          if (hasExample) ...[
            const SizedBox(height: 10),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                // একটু আলাদা background যাতে meaning থেকে distinguish হয়
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // quote icon
                  const Text(
                    '"',
                    style: TextStyle(
                      color: kPurpleLight,
                      fontSize: 22,
                      height: 1.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _HighlightedSentence(
                      sentence: note.exampleSentence,
                      word: note.word,
                      highlightColor: color,
                    ),
                  ),
                  const SizedBox(width: 4),
                  // sentence pronounce button
                  GestureDetector(
                    onTap: () => _speak(note.exampleSentence),
                    child: const Icon(Icons.record_voice_over_rounded,
                        color: kPurpleLight, size: 18),
                  ),
                ],
              ),
            ),
          ],

          // ── Action buttons ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Word TTS
                IconButton(
                  icon: const Icon(Icons.volume_up_rounded,
                      color: kPurpleLight, size: 22),
                  onPressed: () => _speak(note.word),
                  tooltip: 'Pronounce word',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 16),
                // Remove
                IconButton(
                  icon: const Icon(Icons.bookmark_remove_rounded,
                      color: Color(0xFFF87171), size: 22),
                  onPressed: () => _removeFromNotebook(note),
                  tooltip: 'Remove from notebook',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Example sentence এ target word টা highlight করে দেখায়।
/// case-insensitive match — word এর যেকোনো form highlight হবে।
class _HighlightedSentence extends StatelessWidget {
  final String sentence;
  final String word;
  final Color highlightColor;

  const _HighlightedSentence({
    required this.sentence,
    required this.word,
    required this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    if (word.isEmpty || sentence.isEmpty) {
      return Text(sentence,
          style: const TextStyle(
              color: Colors.white60,
              fontSize: 13,
              fontStyle: FontStyle.italic));
    }

    // case-insensitive এ word খুঁজে বের করে highlight করো
    final lowerSentence = sentence.toLowerCase();
    final lowerWord = word.toLowerCase();

    final spans = <TextSpan>[];
    int start = 0;

    while (true) {
      final idx = lowerSentence.indexOf(lowerWord, start);
      if (idx == -1) {
        // বাকি অংশ normal style এ
        if (start < sentence.length) {
          spans.add(TextSpan(text: sentence.substring(start)));
        }
        break;
      }
      // idx এর আগের অংশ
      if (idx > start) {
        spans.add(TextSpan(text: sentence.substring(start, idx)));
      }
      // matched অংশ — highlight
      spans.add(TextSpan(
        text: sentence.substring(idx, idx + word.length),
        style: TextStyle(
          color: highlightColor,
          fontWeight: FontWeight.bold,
          fontStyle: FontStyle.normal,
        ),
      ));
      start = idx + word.length;
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(
            color: Colors.white60,
            fontSize: 13,
            fontStyle: FontStyle.italic,
            height: 1.4),
        children: spans,
      ),
    );
  }
}
