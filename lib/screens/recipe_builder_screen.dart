import 'package:flutter/material.dart';
import '../database/database.dart';

class RecipeBuilderScreen extends StatefulWidget {
  const RecipeBuilderScreen({super.key});

  @override
  State<RecipeBuilderScreen> createState() => _RecipeBuilderScreenState();
}

class _DraftItem {
  final Map<String, dynamic> ingredient; // ingredients row
  final Map<String, dynamic> unit;       // ingredient_units row
  final double quantity;

  const _DraftItem(this.ingredient, this.unit, this.quantity);

  double get grams => quantity * (unit['gram_equivalent'] as num).toDouble();
}

class _RecipeBuilderScreenState extends State<RecipeBuilderScreen> {
  final _name = TextEditingController();
  final _servings = TextEditingController(text: '1');
  final _cookedWeight = TextEditingController();
  final List<_DraftItem> _items = [];

  Future<void> _addItemDialog() async {
    final db = await AppDatabase.instance.database;
    final ingredients = await db.query('ingredients', orderBy: 'name');
    if (ingredients.isEmpty || !mounted) return;

    Map<String, dynamic>? chosenIngredient = ingredients.first;
    List<Map<String, dynamic>> units = [];
    Map<String, dynamic>? chosenUnit;
    final qtyController = TextEditingController(text: '1');

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Add Ingredient'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Pick ingredient (with prep method)
              DropdownButtonFormField<Map<String, dynamic>>(
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Ingredient'),
                value: chosenIngredient,
                items: ingredients
                    .map((ing) => DropdownMenuItem(
                          value: ing,
                          child: Text(
                            '${ing['name']} (${ing['prep_method']})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                onChanged: (v) async {
                  chosenIngredient = v;
                  units = await db.query(
                    'ingredient_units',
                    where: 'ingredient_id = ?',
                    whereArgs: [v!['id']],
                  );
                  chosenUnit = units.isNotEmpty ? units.first : null;
                  setDialogState(() {});
                },
              ),
              const SizedBox(height: 12),
              // 2. Pick unit (g, scoop, piece...)
              DropdownButtonFormField<Map<String, dynamic>>(
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Unit'),
                value: chosenUnit,
                items: units
                    .map((u) => DropdownMenuItem(
                          value: u,
                          child: Text(
                            '${u['unit_name']} (= ${u['gram_equivalent']}g)',
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setDialogState(() => chosenUnit = v),
              ),
              const SizedBox(height: 12),
              // 3. Quantity
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (chosenIngredient != null &&
                    chosenUnit != null &&
                    qtyController.text.isNotEmpty) {
                  setState(() {
                    _items.add(_DraftItem(
                      chosenIngredient!,
                      chosenUnit!,
                      double.tryParse(qtyController.text) ?? 1,
                    ));
                  });
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, double> get _totals {
    double kcal = 0, p = 0, c = 0, f = 0, cost = 0;
    for (final item in _items) {
      final g = item.grams;
      final ing = item.ingredient;
      kcal += ing['cal_per_100g'] * g / 100;
      p += ing['p_per_100g'] * g / 100;
      c += ing['c_per_100g'] * g / 100;
      f += ing['f_per_100g'] * g / 100;
      cost += g * (ing['price_per_kg'] as num).toDouble() / 1000;
    }
    return {'kcal': kcal, 'p': p, 'c': c, 'f': f, 'cost': cost};
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _items.isEmpty) return;
    final db = await AppDatabase.instance.database;
    final recipeId = await db.insert('recipes', {
      'name': _name.text.trim(),
      'servings': int.tryParse(_servings.text) ?? 1,
      'total_cooked_weight_g': double.tryParse(_cookedWeight.text) ?? 0,
    });
    for (final item in _items) {
      await db.insert('recipe_items', {
        'recipe_id': recipeId,
        'ingredient_id': item.ingredient['id'],
        'unit_id': item.unit['id'],
        'quantity': item.quantity,
        'calculated_grams': item.grams,
      });
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = _totals;
    final servings = int.tryParse(_servings.text) ?? 1;

    return Scaffold(
      appBar: AppBar(title: const Text('Recipe Builder')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Recipe name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _servings,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Servings',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _cookedWeight,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Cooked weight (g)',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Live totals card
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text(
                    'Batch: ${t['kcal']!.toStringAsFixed(0)} kcal • '
                    'P ${t['p']!.toStringAsFixed(1)}g • C ${t['c']!.toStringAsFixed(1)}g • F ${t['f']!.toStringAsFixed(1)}g',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('Batch cost: ${t['cost']!.toStringAsFixed(2)}'),
                  const Divider(),
                  Text(
                    'Per serving (${servings}x): '
                    '${(t['kcal']! / servings).toStringAsFixed(0)} kcal • '
                    'cost ${(t['cost']! / servings).toStringAsFixed(2)}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, i) {
                final item = _items[i];
                return ListTile(
                  title: Text(
                    '${item.quantity} × ${item.unit['unit_name']} ${item.ingredient['name']}',
                  ),
                  subtitle: Text('= ${item.grams.toStringAsFixed(1)}g'),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => setState(() => _items.removeAt(i)),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _addItemDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Ingredient'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _save,
                    child: const Text('Save Recipe'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
