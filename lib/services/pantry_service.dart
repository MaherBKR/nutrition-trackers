import '../database/database.dart';

class PantryService {
  /// Subtracts [grams] from an ingredient's pantry stock.
  /// If stock falls below min threshold, auto-adds the gap to the shopping list.
  static Future<void> deductStock(int ingredientId, double grams) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('pantry_shopping',
        where: 'ingredient_id = ?', whereArgs: [ingredientId]);

    Map<String, dynamic> row;
    if (rows.isEmpty) {
      final id = await db.insert('pantry_shopping', {
        'ingredient_id': ingredientId,
        'current_stock_g': 0,
        'min_threshold_g': 0,
      });
      row = {'id': id, 'current_stock_g': 0, 'min_threshold_g': 0};
    } else {
      row = rows.first;
    }

    final newStock =
        ((row['current_stock_g'] as num).toDouble() - grams).clamp(0.0, 1e9);
    final threshold = (row['min_threshold_g'] as num).toDouble();
    final toBuy = newStock < threshold ? threshold - newStock : 0;

    await db.update(
      'pantry_shopping',
      {'current_stock_g': newStock, 'to_buy_qty': toBuy},
      where: 'id = ?',
      whereArgs: [row['id']],
    );
  }
}
