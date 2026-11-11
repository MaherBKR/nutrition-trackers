import 'package:flutter/material.dart';
import '../database/database.dart';

class PantryScreen extends StatefulWidget {
  const PantryScreen({super.key});

  @override
  State<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends State<PantryScreen> {
  late Future<List<Map<String, dynamic>>> _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _items = AppDatabase.instance.database.then((db) => db.rawQuery('''
      SELECT i.id AS ingredient_id, i.name, i.category,
             COALESCE(p.current_stock_g, 0) AS stock,
             COALESCE(p.min_threshold_g, 0) AS threshold,
             p.id AS pantry_id
      FROM ingredients i
      LEFT JOIN pantry_shopping p ON p.ingredient_id = i.id
      WHERE i.prep_method = (
        SELECT MIN(prep_method) FROM ingredients i2 WHERE i2.name = i.name
      )
      ORDER BY i.category, i.name
    '''));
  }

  Future<void> _editStock(Map<String, dynamic> item) async {
    final db = await AppDatabase.instance.database;
    final stockCtrl = TextEditingController(text: '${item['stock']}');
    final threshCtrl = TextEditingController(text: '${item['threshold']}');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${item['name']} stock'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: stockCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Current stock (g)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: threshCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Min threshold (g)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );

    if (ok == true) {
      final stock = double.tryParse(stockCtrl.text) ?? 0;
      final thresh = double.tryParse(threshCtrl.text) ?? 0;
      if (item['pantry_id'] == null) {
        await db.insert('pantry_shopping', {
          'ingredient_id': item['ingredient_id'],
          'current_stock_g': stock,
          'min_threshold_g': thresh,
          'to_buy_qty': stock < thresh ? thresh - stock : 0,
        });
      } else {
        await db.update(
          'pantry_shopping',
          {
            'current_stock_g': stock,
            'min_threshold_g': thresh,
            'to_buy_qty': stock < thresh ? thresh - stock : 0,
          },
          where: 'id = ?',
          whereArgs: [item['pantry_id']],
        );
      }
      setState(_load);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pantry')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _items,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return const Center(child: Text('No ingredients in catalog.'));
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) {
              final it = items[i];
              final low = (it['stock'] as num) < (it['threshold'] as num);
              return ListTile(
                leading: Icon(
                  low ? Icons.warning_amber : Icons.inventory_2,
                  color: low ? Colors.orange : Colors.teal,
                ),
                title: Text(it['name']),
                subtitle: Text(
                  '${it['category']} • ${it['stock']}g in stock'
                  '${(it['threshold'] as num) > 0 ? ' • min ${it['threshold']}g' : ''}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editStock(it),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
