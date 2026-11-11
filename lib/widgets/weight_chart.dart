import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../database/database.dart';

class WeightChart extends StatefulWidget {
  const WeightChart({super.key});

  @override
  State<WeightChart> createState() => _WeightChartState();
}

class _WeightChartState extends State<WeightChart> {
  List<FlSpot> _daily = [];
  List<FlSpot> _ema = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await AppDatabase.instance.database;
    // Latest weight per date, oldest first
    final rows = await db.rawQuery('''
      SELECT date, morning_weight_kg FROM daily_logs
      WHERE meal_slot = 'Weight' AND morning_weight_kg IS NOT NULL
      GROUP BY date HAVING MAX(id)
      ORDER BY date ASC
    ''');

    final daily = <FlSpot>[];
    final ema = <FlSpot>[];
    const alpha = 2 / (7 + 1); // 7-day EMA
    double? prevEma;

    for (var i = 0; i < rows.length; i++) {
      final w = (rows[i]['morning_weight_kg'] as num).toDouble();
      daily.add(FlSpot(i.toDouble(), w));
      prevEma = prevEma == null ? w : alpha * w + (1 - alpha) * prevEma;
      ema.add(FlSpot(i.toDouble(), prevEma));
    }

    setState(() {
      _daily = daily;
      _ema = ema;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_daily.isEmpty) {
      return const SizedBox(
        height: 220,
        child: Center(child: Text('Log your morning weight to see the trend')),
      );
    }
    return SizedBox(
      height: 220,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LineChart(
          LineChartData(
            gridData: const FlGridData(show: false),
            titlesData: const FlTitlesData(show: false),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              // Daily weigh-ins: visible dots, nearly invisible line
              LineChartBarData(
                spots: _daily,
                isCurved: false,
                color: Colors.transparent,
                barWidth: 0,
                dotData: const FlDotData(show: true),
              ),
              // 7-day EMA trend line
              LineChartBarData(
                spots: _ema,
                isCurved: true,
                color: Colors.teal,
                barWidth: 3,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: Colors.teal.withOpacity(0.1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
