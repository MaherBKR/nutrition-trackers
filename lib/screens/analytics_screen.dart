import 'package:flutter/material.dart';
import '../widgets/weight_chart.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: ListView(
        children: const [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text('Weight Trend',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          WeightChart(),
          Divider(),
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Coming soon: weekly calorie/protein consistency bars '
              'and grocery spend trend (Phase 4).',
            ),
          ),
        ],
      ),
    );
  }
}
