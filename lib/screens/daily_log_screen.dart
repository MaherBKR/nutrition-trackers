import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database.dart';
import '../widgets/macro_ring.dart';
import '../services/pantry_service.dart';

class DailyLogScreen extends StatefulWidget {
  const DailyLogScreen({super.key});

  @override
  State<DailyLogScreen> createState() => _DailyLogScreenState();
}

class _DailyLogScreenState extends State<DailyLogScreen> {
  late String _date;
  List<Map<String, dynamic>> _logs = [];
  double _kcal = 0, _p = 0, _c = 0, _f = 0, _water = 0;
  double? _weight;

  static const _mealSlots = ['Breakfast', 'Lunch', 'Dinner', 'Snack', 'Supplements'];

  @override
  void initState() {
    super.initState();
    _date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _load();
  }

  Future<void> _load() async {
    final db = await AppDatabase.instance.database;
    final logs = await db.query('daily_logs',
        where: 'date = ?', whereArgs: [_date], orderBy: 'id');

    double kcal = 0, p = 0, c = 0, f = 0, water = 0;
    double? weight;

    for (final log in logs) {
      if (log['meal_slot'] == 'Water') {
        water += (log['water_ml'] as num).toDouble();
        continue;
      }
      if (log['meal_slot'] == 'Weight') {
        weight = (log['morning_weight_kg'] as num?)?.toDouble();
        continue;
      }
      final m = await _macrosFor(log, db);
      kcal += m['kcal']!;
      p += m['p']!;
      c += m['c']!;
      f += m['f']!;
    }

    setState(() {
      _logs = logs;
      _kcal = kcal; _p = p; _c = c; _f = f;
      _water = water; _weight = weight;
    });
  }

  Future<Map<String, double>> _macrosFor(
      Map<String, dynamic> log, dynamic db) async {
    final grams = (log['grams_consumed'] as num).toDouble();
    if (log['source_type'] == 'Ingredient') {
      final rows = await db.query('ingredients',
          where: 'id = ?', whereArgs: [log['source_id']], limit: 1);
      if (rows.isEmpty) return {'kcal': 0, 'p': 0, 'c': 0, 'f': 0};
      final ing = rows.first;
      return {
        'kcal': ing['cal_per_100g'] * grams / 100,
        'p': ing['p_per_100g'] * grams / 100,
        'c': ing['c_per_100g'] * grams / 100,
        'f': ing['f_per_100g'] * grams / 100,
      };
    } else {
      // Recipe: batch totals scaled by portion of cooked weight
      final recipes = await db.query('recipes',
          where: 'id = ?', whereArgs: [log['source_id']], limit: 1);
      if (recipes.isEmpty) return {'kcal': 0, 'p': 0, 'c': 0, 'f': 0};
      final items = await db.rawQuery('''
        SELECT ri.calculated_grams, i.cal_per_100g, i.p_per_100g, i.c_per_100g, i.f_per_100g
        FROM recipe_items ri JOIN ingredients i ON i.id = ri.ingredient_id
        WHERE ri.recipe_id = ?
      ''', [log['source_id']]);
      double kcal = 0, p = 0, c = 0, f = 0, batchG = 0;
      for (final it in items) {
        final g = (it['calculated_grams'] as num).toDouble();
        batchG += g;
        kcal += it['cal_per_100g'] * g / 100;
        p += it['p_per_100g'] * g / 100;
        c += it['c_per_100g'] * g / 100;
        f += it['f_per_100g'] * g / 100;
      }
      final cooked = (recipes.first['total_cooked_weight_g'] as num).toDouble();
      final base = cooked > 0 ? cooked : batchG;
      final factor = base > 0 ? grams / base : 0;
      return {'kcal': kcal * factor, 'p': p * factor, 'c': c * factor, 'f': f * factor};
    }
  }

  Future<void> _addWater(double ml) async {
    final db = await AppDatabase.instance.database;
    await db.insert('daily_logs', {
      'date': _date, 'meal_slot': 'Water', 'source_type': 'None',
      'source_id': 0, 'grams_consumed': 0, 'water_ml': ml,
    });
    _load();
  }

  Future<void> _setWeight() async {
    final controller = TextEditingController(
        text: _weight?.toString() ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Morning weight (kg)'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Save')),
        ],
      ),
    );
    if (result != null && double.tryParse(result) != null) {
      final db = await AppDatabase.instance.database;
      await db.insert('daily_logs', {
        'date': _date, 'meal_slot': 'Weight', 'source_type': 'None',
        'source_id': 0, 'grams_consumed': 0,
        'morning_weight_kg': double.parse(result),
      });
      _load();
    }
  }

  Future<void> _addFoodDialog() async {
    final db = await AppDatabase.instance.database;
    String sourceType = 'Ingredient';
    List<Map<String, dynamic>> sources = await db.query('ingredients', orderBy: 'name');
    Map<String, dynamic>? chosen = sources.isNotEmpty ? sources.first : null;
    String mealSlot = _mealSlots.first;
    final gramsController = TextEditingController(text: '100');

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Log Food'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: mealSlot,
                decoration: const InputDecoration(labelText: 'Meal'),
                items: _mealSlots
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) => setDialogState(() => mealSlot = v!),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: sourceType,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'Ingredient', child: Text('Ingredient')),
                  DropdownMenuItem(value: 'Recipe', child: Text('Recipe')),
                ],
                onChanged: (v) async {
                  sourceType = v!;
                  sources = await db.query(
                      v == 'Ingredient' ? 'ingredients' : 'recipes',
                      orderBy: 'name');
                  chosen = sources.isNotEmpty ? sources.first : null;
                  setDialogState(() {});
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<Map<String, dynamic>>(
                isExpanded: true,
                decoration: InputDecoration(
                    labelText: sourceType == 'Ingredient' ? 'Ingredient' : 'Recipe'),
                value: chosen,
                items: sources
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(
                            sourceType == 'Ingredient'
                                ? '${s['name']} (${s['prep_method']})'
                                : s['name'],
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setDialogState(() => chosen = v),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: gramsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Grams'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (chosen == null) return;
                await db.insert('daily_logs', {
                  'date': _date,
                  'meal_slot': mealSlot,
                  'source_type': sourceType,
                  'source_id': chosen!['id'],
                  'grams_consumed': double.tryParse(gramsController.text) ?? 0,
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              },
              child: const Text('Log'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final foodLogs = _logs
        .where((l) => l['meal_slot'] != 'Water' && l['meal_slot'] != 'Weight')
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text('Today • $_date')),
      body: ListView(
        children: [
          MacroRing(consumedKcal: _kcal, protein: _p, carbs: _c, fat: _f),
          // Water tracker
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Water: ${_water.toStringAsFixed(0)} ml',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final ml in [250.0, 330.0, 500.0])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            avatar: const Icon(Icons.water_drop, size: 18),
                            label: Text('+${ml.toStringAsFixed(0)}'),
                            onPressed: () => _addWater(ml),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Weight
          ListTile(
            leading: const Icon(Icons.monitor_weight),
            title: const Text('Morning weight'),
            subtitle: Text(_weight != null ? '${_weight} kg' : 'Not logged'),
            trailing: TextButton(
                onPressed: _setWeight,
                child: Text(_weight != null ? 'Update' : 'Log')),
          ),
          const Divider(),
          for (final log in foodLogs)
            ListTile(
              dense: true,
              title: Text('${log['meal_slot']} • ${log['source_type']} #${log['source_id']}'),
              subtitle: Text('${log['grams_consumed']}g'),
            ),
          const SizedBox(height: 80),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addFoodDialog,
        icon: const Icon(Icons.add),
        label: const Text('Log food'),
      ),
    );
  }
}
