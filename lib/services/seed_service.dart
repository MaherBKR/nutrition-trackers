import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database.dart';

class SeedService {
  static const _seededKey = 'seed_loaded';

  static Future<void> seedIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_seededKey) ?? false) return;

    final db = await AppDatabase.instance.database;
    final jsonString =
        await rootBundle.loadString('assets/seed_ingredients.json');
    final data = json.decode(jsonString) as Map<String, dynamic>;

    for (final item in data['ingredients'] as List<dynamic>) {
      final preparations = item['preparations'] as List<dynamic>;
      // One DB row per preparation variant
      for (final prep in preparations) {
        final ingredientId = await db.insert('ingredients', {
          'name': item['name'],
          'category': item['category'],
          'prep_method': prep['prep_method'],
          'cal_per_100g': prep['cal_per_100g'],
          'p_per_100g': prep['p_per_100g'],
          'c_per_100g': prep['c_per_100g'],
          'f_per_100g': prep['f_per_100g'],
        });

        for (final unit in item['units'] as List<dynamic>) {
          await db.insert('ingredient_units', {
            'ingredient_id': ingredientId,
            'unit_name': unit['unit_name'],
            'gram_equivalent': unit['gram_equivalent'],
          });
        }
      }
    }

    await prefs.setBool(_seededKey, true);
  }
}
