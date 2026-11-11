import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database.dart';

class BackupService {
  static const _tables = [
    'ingredients', 'ingredient_units', 'recipes', 'recipe_items',
    'daily_logs', 'pantry_shopping', 'reminders',
  ];

  /// Exports every table into nutrition_backup_YYYY_MM_DD.json.
  /// Returns the file path.
  static Future<String> exportJson() async {
    final db = await AppDatabase.instance.database;
    final bundle = <String, dynamic>{};
    for (final t in _tables) {
      bundle[t] = await db.query(t);
    }
    final dir = await getApplicationDocumentsDirectory();
    final stamp = DateFormat('yyyy_MM_dd').format(DateTime.now());
    final file = File('${dir.path}/nutrition_backup_$stamp.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(bundle));
    return file.path;
  }

  /// Restores from a JSON bundle.
  /// overwrite=true: wipe all tables first (new phone scenario).
  /// overwrite=false: merge — only adds rows whose id doesn't already exist.
  static Future<int> restoreJson(String path,
      {required bool overwrite}) async {
    final db = await AppDatabase.instance.database;
    final data =
        json.decode(await File(path).readAsString()) as Map<String, dynamic>;

    if (overwrite) {
      for (final t in _tables.reversed) {
        await db.delete(t);
      }
    }

    var count = 0;
    for (final t in _tables) {
      for (final row in (data[t] as List<dynamic>? ?? [])) {
        await db.insert(
          t,
          Map<String, dynamic>.from(row as Map),
          conflictAlgorithm:
              overwrite ? ConflictAlgorithm.replace : ConflictAlgorithm.ignore,
        );
        count++;
      }
    }
    return count;
  }

  /// Exports weight history and raw daily logs as CSV files.
  static Future<List<String>> exportCsv() async {
    final db = await AppDatabase.instance.database;
    final dir = await getApplicationDocumentsDirectory();

    final wRows = await db.rawQuery("""
      SELECT date, morning_weight_kg FROM daily_logs
      WHERE meal_slot = 'Weight' AND morning_weight_kg IS NOT NULL
      ORDER BY date
    """);
    final wBuf = StringBuffer('date,weight_kg\n');
    for (final r in wRows) {
      wBuf.writeln('${r['date']},${r['morning_weight_kg']}');
    }
    final wFile = File('${dir.path}/weight_log.csv');
    await wFile.writeAsString(wBuf.toString());

    final lRows = await db.query('daily_logs', orderBy: 'date, id');
    final lBuf = StringBuffer(
        'date,meal_slot,source_type,source_id,grams_consumed,water_ml,morning_weight_kg\n');
    for (final r in lRows) {
      lBuf.writeln(
          '${r['date']},${r['meal_slot']},${r['source_type']},${r['source_id']},'
          '${r['grams_consumed']},${r['water_ml']},${r['morning_weight_kg']}');
    }
    final lFile = File('${dir.path}/daily_log.csv');
    await lFile.writeAsString(lBuf.toString());

    return [wFile.path, lFile.path];
  }
}
