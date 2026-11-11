import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class MacroRing extends StatelessWidget {
  final double consumedKcal;
  final double protein, carbs, fat;
  final double targetKcal = 2000;
  final double targetP = 150, targetC = 200, targetF = 70;

  const MacroRing({
    super.key,
    required this.consumedKcal,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (consumedKcal / targetKcal).clamp(0.0, 1.0);

    Widget macroBar(String label, double grams, double target, Color color) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 70,
              child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: LinearProgressIndicator(
                value: (grams / target).clamp(0.0, 1.0),
                minHeight: 10,
                borderRadius: BorderRadius.circular(5),
                color: color,
                backgroundColor: color.withValues(alpha: 0.2),
              ),
            ),
            SizedBox(
              width: 90,
              child: Text(
                ' ${grams.toStringAsFixed(0)}/${target.toStringAsFixed(0)}g',
                textAlign: TextAlign.end,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 150,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      startDegreeOffset: -90,
                      centerSpaceRadius: 55,
                      sectionsSpace: 2,
                      sections: [
                        PieChartSectionData(
                          value: pct * 100,
                          color: Colors.teal,
                          showTitle: false,
                          radius: 18,
                        ),
                        PieChartSectionData(
                          value: (1 - pct) * 100,
                          color: Colors.grey.shade300,
                          showTitle: false,
                          radius: 18,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        consumedKcal.toStringAsFixed(0),
                        style: const TextStyle(
                          fontSize: 28, fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text('of ${targetKcal.toStringAsFixed(0)} kcal'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            macroBar('Protein', protein, targetP, Colors.redAccent),
            macroBar('Carbs', carbs, targetC, Colors.amber),
            macroBar('Fat', fat, targetF, Colors.purple),
          ],
        ),
      ),
    );
  }
}
