import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const _bg = Color(0xFF0A0A14);
  static const _card = Color(0xFF1A1A2E);
  static const _border = Color(0xFF2A2A45);
  static const _purple = Color(0xFF7C3AED);
  static const _textSecondary = Color(0xFF8B8BAD);

  bool _loading = true;
  List<Map<String, dynamic>> _sessions = [];

  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await SupabaseService.fetchSessionHistory();
    setState(() {
      _sessions = data;
      _loading = false;
    });
  }

  Map<String, List<Map<String, dynamic>>> _groupByMonth() {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final s in _sessions) {
      final createdAt = DateTime.parse(s['created_at']).toLocal();
      final key = '${_monthNames[createdAt.month - 1]} ${createdAt.year}';
      grouped.putIfAbsent(key, () => []).add(s);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByMonth();

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title:
            const Text('Result History', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _purple))
          : _sessions.isEmpty
              ? const Center(
                  child: Text('এখনো কোনো session খেলা হয়নি',
                      style: TextStyle(color: _textSecondary)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: grouped.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${entry.key} • ${entry.value.length} বার খেলেছেন',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          ...entry.value.map((s) => _sessionCard(s)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
    );
  }

  Widget _sessionCard(Map<String, dynamic> s) {
    final wpm = (s['wpm'] as num).toDouble();
    final accuracy = (s['accuracy'] as num).toDouble();
    final timePlayed = s['time_played'] as int;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _miniStat('⚡', '${wpm.toStringAsFixed(1)} WPM'),
          _miniStat('🎯', '${accuracy.toStringAsFixed(1)}%'),
          _miniStat('⏱️', '${timePlayed}s'),
        ],
      ),
    );
  }

  Widget _miniStat(String emoji, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ],
    );
  }
}
