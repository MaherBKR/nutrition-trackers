import 'package:flutter/material.dart';
import '../database/database.dart';
import 'recipe_builder_screen.dart';

class RecipeListScreen extends StatefulWidget {
  const RecipeListScreen({super.key});

  @override
  State<RecipeListScreen> createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends State<RecipeListScreen> {
  late Future<List<Map<String, dynamic>>> _recipes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _recipes = AppDatabase.instance.database.then(
      (db) => db.query('recipes', orderBy: 'name'),
    );
  }

  Future<void> _delete(int id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('recipes', where: 'id = ?', whereArgs: [id]);
    setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recipes')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _recipes,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return const Center(child: Text('No recipes yet.'));
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) {
              final r = items[i];
              return ListTile(
                leading: r['is_favorite'] == 1
                    ? const Icon(Icons.star, color: Colors.amber)
                    : const Icon(Icons.restaurant_menu),
                title: Text(r['name']),
                subtitle: Text(
                  '${r['servings']} serving(s)'
                  '${r['total_cooked_weight_g'] > 0 ? ' • ${r['total_cooked_weight_g']}g cooked' : ''}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(r['id']),
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
            MaterialPageRoute(builder: (_) => const RecipeBuilderScreen()),
          );
          setState(_load);
        },
      ),
    );
  }
}
