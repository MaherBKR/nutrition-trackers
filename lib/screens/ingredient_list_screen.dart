import 'package:flutter/material.dart';
import '../database/database.dart';
import 'ingredient_form_screen.dart';

class IngredientListScreen extends StatefulWidget {
  const IngredientListScreen({super.key});

  @override
  State<IngredientListScreen> createState() => _IngredientListScreenState();
}

class _IngredientListScreenState extends State<IngredientListScreen> {
  late Future<List<Map<String, dynamic>>> _ingredients;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _ingredients = AppDatabase.instance.database.then(
      (db) => db.query('ingredients', orderBy: 'category, name'),
    );
  }

  Future<void> _delete(int id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('ingredients', where: 'id = ?', whereArgs: [id]);
    setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ingredients')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _ingredients,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return const Center(child: Text('No ingredients yet.'));
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) {
              final it = items[i];
              return ListTile(
                title: Text('${it['name']} (${it['prep_method']})'),
                subtitle: Text(
                  '${it['category']} • ${it['cal_per_100g']} kcal • '
                  'P ${it['p_per_100g']}g / C ${it['c_per_100g']}g / F ${it['f_per_100g']}g per 100g',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(it['id']),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const IngredientFormScreen()),
          );
          setState(_load);
        },
      ),
    );
  }
}
