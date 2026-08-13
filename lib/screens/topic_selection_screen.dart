import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/topic.dart';
import 'game_screen.dart';

class TopicSelectionScreen extends StatefulWidget {
  final String mode;
  final String gameType;

  const TopicSelectionScreen({
    super.key,
    required this.mode,
    this.gameType = 'survival',
  });

  @override
  State<TopicSelectionScreen> createState() => _TopicSelectionScreenState();
}

class _TopicSelectionScreenState extends State<TopicSelectionScreen> {
  List<Topic> _topics = [];
  final Set<int> _selectedIds = {};
  bool _loading = true;

  static const _bg = Color(0xFF0A0A14);
  static const _purple = Color(0xFF7C3AED);
  static const _accent = Color(0xFFC084FC);
  static const _textSecondary = Color(0xFF8B8BAD);

  @override
  void initState() {
    super.initState();
    _loadTopics();
  }

  Future<void> _loadTopics() async {
    try {
      final data =
          await Supabase.instance.client.from('topics').select().order('id');

      if (!mounted) return;

      setState(() {
        _topics =
            List<Map<String, dynamic>>.from(data).map(Topic.fromMap).toList();

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load topics: $e'),
        ),
      );
    }
  }

  void _toggle(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _start() {
    final selected =
        _topics.where((topic) => _selectedIds.contains(topic.id)).toList();

    if (selected.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(
          mode: widget.mode,
          gameType: widget.gameType,
          topics: selected,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = _selectedIds.isNotEmpty;

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // Top purple glow
          Positioned(
            top: -120,
            left: -80,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _purple.withOpacity(0.2),
              ),
            ),
          ),

          // Bottom purple glow
          Positioned(
            bottom: -100,
            right: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _accent.withOpacity(0.12),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Back button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back_ios_rounded,
                        color: Colors.white70,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Mode title
                  Text(
                    widget.mode == 'easy' ? '🟢 Word Pop' : '🔴 Synonym Pop',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Subtitle
                  Text(
                    hasSelection
                        ? '${_selectedIds.length} topic${_selectedIds.length > 1 ? 's' : ''} selected — tap more or start'
                        : 'Select one or more topics to begin',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _textSecondary,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Topics
                  Expanded(
                    child: _loading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: _purple,
                            ),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              // Available width for each square box
                              final boxWidth = (constraints.maxWidth - 16) / 2;

                              return GridView.builder(
                                padding: const EdgeInsets.only(
                                  bottom: 10,
                                ),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,

                                  // Gap between columns
                                  crossAxisSpacing: 16,

                                  // Gap between rows
                                  mainAxisSpacing: 16,

                                  // EXACT square height
                                  mainAxisExtent: boxWidth,
                                ),
                                itemCount: _topics.length,
                                itemBuilder: (context, index) {
                                  final topic = _topics[index];

                                  final selected =
                                      _selectedIds.contains(topic.id);

                                  return GestureDetector(
                                    onTap: () => _toggle(topic.id),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? topic.themeColor.withOpacity(
                                                0.35,
                                              )
                                            : topic.bgColor.withOpacity(
                                                0.3,
                                              ),
                                        borderRadius: BorderRadius.circular(
                                          16,
                                        ),
                                        border: Border.all(
                                          color: selected
                                              ? topic.themeColor
                                              : topic.themeColor.withOpacity(
                                                  0.5,
                                                ),
                                          width: selected ? 2.5 : 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: topic.themeColor.withOpacity(
                                              selected ? 0.4 : 0.2,
                                            ),
                                            blurRadius: selected ? 18 : 12,
                                            offset: const Offset(
                                              0,
                                              4,
                                            ),
                                          ),
                                        ],
                                      ),
                                      child: Stack(
                                        children: [
                                          // Emoji + topic name
                                          Center(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  topic.emoji,
                                                  style: const TextStyle(
                                                    fontSize: 40,
                                                  ),
                                                ),
                                                const SizedBox(
                                                  height: 10,
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 8,
                                                  ),
                                                  child: Text(
                                                    topic.name,
                                                    textAlign: TextAlign.center,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Selected check mark
                                          if (selected)
                                            Positioned(
                                              top: 8,
                                              right: 8,
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  3,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: topic.themeColor,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.check,
                                                  size: 14,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                  ),

                  const SizedBox(height: 16),

                  // Start button
                  ElevatedButton(
                    onPressed: hasSelection ? _start : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _purple,
                      disabledBackgroundColor: const Color(0xFF2A2A45),
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      hasSelection ? 'Start Game 🎈' : 'Select a topic',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
