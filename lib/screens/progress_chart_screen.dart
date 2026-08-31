import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/supabase_service.dart';

class ProgressChartScreen extends StatefulWidget {
  const ProgressChartScreen({super.key});

  @override
  State<ProgressChartScreen> createState() => _ProgressChartScreenState();
}

class _ProgressChartScreenState extends State<ProgressChartScreen> {
  static const _bg = Color(0xFF0A0A14);
  static const _purple = Color(0xFF7C3AED);
  static const _accent = Color(0xFFC084FC);
  static const _textSecondary = Color(0xFF8B8BAD);

  bool _loading = true;
  List<Map<String, dynamic>> _sessions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await SupabaseService.fetchSessionHistory();
    data.sort((a, b) => DateTime.parse(a['created_at'])
        .compareTo(DateTime.parse(b['created_at'])));
    setState(() {
      _sessions = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final maxWpm = _sessions.isEmpty
        ? 100.0
        : _sessions
            .map((s) => (s['wpm'] as num).toDouble())
            .reduce((a, b) => a > b ? a : b);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title:
            const Text('WPM Progress', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _purple))
          : _sessions.length < 2
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Play atleast two times !!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _textSecondary)),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(12, 24, 24, 24),
                  child: LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: (maxWpm * 1.2).ceilToDouble(),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (v) =>
                            FlLine(color: Colors.white10, strokeWidth: 1),
                      ),
                      titlesData: FlTitlesData(
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 24,
                            getTitlesWidget: (value, meta) {
                              final i = value.toInt();
                              if (i < 0 || i >= _sessions.length) {
                                return const SizedBox.shrink();
                              }
                              return Text('${i + 1}',
                                  style: const TextStyle(
                                      color: _textSecondary, fontSize: 10));
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 42,
                            getTitlesWidget: (value, meta) => Text(
                                '${value.toInt()}',
                                style: const TextStyle(
                                    color: _textSecondary, fontSize: 10)),
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: List.generate(_sessions.length, (i) {
                            final wpm = (_sessions[i]['wpm'] as num).toDouble();
                            return FlSpot(i.toDouble(), wpm);
                          }),
                          isCurved: true,
                          color: _accent,
                          barWidth: 3,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                              show: true, color: _purple.withOpacity(0.15)),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
