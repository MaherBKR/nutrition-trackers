import 'package:flutter/material.dart';
import '../database/database.dart';

class IngredientFormScreen extends StatefulWidget {
  const IngredientFormScreen({super.key});

  @override
  State<IngredientFormScreen> createState() => _IngredientFormScreenState();
}

class _IngredientFormScreenState extends State<IngredientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _cal = TextEditingController();
  final _p = TextEditingController();
  final _c = TextEditingController();
  final _f = TextEditingController();
  final _price = TextEditingController();

  String _category = 'Poultry & Meat';
  String _prep = 'Raw';

  static const _categories = [
    'Poultry & Meat', 'Fish & Seafood', 'Eggs & Dairy',
    'Grains & Wraps', 'Legumes & Veggies', 'Fats & Condiments', 'Supplements',
  ];
  static const _preps = ['Raw', 'Boiled', 'Air-Fried', 'Roasted', 'Pan-Fried', 'Grilled'];

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final db = await AppDatabase.instance.database;
    await db.insert('ingredients', {
      'name': _name.text.trim(),
      'category': _category,
      'prep_method': _prep,
      'cal_per_100g': double.parse(_cal.text),
      'p_per_100g': double.parse(_p.text),
      'c_per_100g': double.parse(_c.text),
      'f_per_100g': double.parse(_f.text),
      'price_per_kg': double.tryParse(_price.text) ?? 0,
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration dec(String label) =>
        InputDecoration(labelText: label, border: const OutlineInputBorder());

    return Scaffold(
      appBar: AppBar(title: const Text('Add Ingredient')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _name,
                decoration: dec('Name (e.g. Chicken Breast)'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField(
                value: _category,
                decoration: dec('Category'),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField(
                value: _prep,
                decoration: dec('Preparation'),
                items: _preps
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (v) => setState(() => _prep = v!),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextFormField(controller: _cal, keyboardType: TextInputType.number, decoration: dec('kcal/100g'), validator: (v) => v!.isEmpty ? 'Req' : null)),
                const SizedBox(width: 8),
                Expanded(child: TextFormField(controller: _p, keyboardType: TextInputType.number, decoration: dec('P/100g'))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextFormField(controller: _c, keyboardType: TextInputType.number, decoration: dec('C/100g'))),
                const SizedBox(width: 8),
                Expanded(child: TextFormField(controller: _f, keyboardType: TextInputType.number, decoration: dec('F/100g'))),
              ]),
              const SizedBox(height: 12),
              TextFormField(
                controller: _price,
                keyboardType: TextInputType.number,
                decoration: dec('Price per kg (optional)'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('Save Ingredient'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
