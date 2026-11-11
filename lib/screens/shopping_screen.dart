import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database.dart';

class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({super.key});

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  late Future<Map<String, dynamic>> _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _data = AppDatabase.instance.database.then((db) async {
      final list = await db.rawQuery('''
        SELECT p.id, p.to_buy_qty, p.actual_price_paid, i.name, i.category, i.price_per_kg
        FROM pantry_shopping p JOIN ingredients i ON i.id = p.ingredient_id
        WHERE p.to_buy_qty > 0
        ORDER BY i.category, i.name
      ''');
      final weekAgo = DateFormat('yyyy-MM-dd')
          .format(DateTime.now().subtract(const Duration(days: 7)));
      final spend = await db.rawQuery('''
        SELECT COALESCE(SUM(actual_price_paid), 0) AS total, COUNT(*) AS items
        FROM pantry_shopping
        WHERE purchased_date >= ?
      ''', [weekAgo]);
      return {'list': list, 'week': spend.first};
    });
  }

  Future<void> _checkOff(Map<String, dynamic> item) async {
    final priceCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Price paid — ${item['name']}'),
        content: TextField(
          controller: priceCtrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
              labelText: 'Actual price (0 = skip recording)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Purchased')),
        ],
      ),
    );
    if (ok != true) return;

    final db = await AppDatabase.instance.database;
    await db.update(
      'pantry_shopping',
      {
        'to_buy_qty': 0,
        'purchased_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'actual_price_paid': double.tryParse(priceCtrl.text) ?? 0,
      },
      where: 'id = ?',
      whereArgs: [item['id']],
    );
    setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shopping List')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _data,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snapshot.data!['list'] as List<Map<String, dynamic>>;
          final week = snapshot.data!['week'];

          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Shopping list is empty 🎉'),
                  const SizedBox(height: 8),
                  Text(
                    'Last 7 days spend: ${(week['total'] as num).toStringAsFixed(2)} '
                    '(${week['items']} purchases)',
                  ),
                ],
              ),
            );
          }

          // Group by category
          final grouped = <String, List<Map<String, dynamic>>>{};
          for (final it in list) {
            grouped.putIfAbsent(it['category'], () => []).add(it);
          }

          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Last 7 days spend: ${(week['total'] as num).toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              for (final entry in grouped.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(entry.key,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.teal)),
                ),
                for (final it in entry.value)
                  ListTile(
                    leading: IconButton(
                      icon: const Icon(Icons.check_circle_outline),
                      onPressed: () => _checkOff(it),
                    ),
                    title: Text(it['name']),
                    subtitle: Text('${it['to_buy_qty']}g to buy'),
                    trailing: (it['price_per_kg'] as num) > 0
                        ? Text(
                            '~${((it['price_per_kg'] as num) * (it['to_buy_qty'] as num) / 1000).toStringAsFixed(2)}',
                          )
                        : null,
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
