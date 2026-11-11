import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;

  AppDatabase._init();

  Future<Database> get database async {
    _database ??= await _initDB('nutrition_tracker.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE ingredients(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        prep_method TEXT NOT NULL DEFAULT 'Raw',
        cal_per_100g REAL NOT NULL,
        p_per_100g REAL NOT NULL,
        c_per_100g REAL NOT NULL,
        f_per_100g REAL NOT NULL,
        unit_price REAL NOT NULL DEFAULT 0,
        price_per_kg REAL NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE ingredient_units(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ingredient_id INTEGER NOT NULL,
        unit_name TEXT NOT NULL,
        gram_equivalent REAL NOT NULL,
        FOREIGN KEY (ingredient_id) REFERENCES ingredients(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE recipes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        total_cooked_weight_g REAL NOT NULL DEFAULT 0,
        servings INTEGER NOT NULL DEFAULT 1,
        prep_notes TEXT NOT NULL DEFAULT '',
        is_favorite INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE recipe_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        recipe_id INTEGER NOT NULL,
        ingredient_id INTEGER NOT NULL,
        unit_id INTEGER NOT NULL,
        quantity REAL NOT NULL,
        calculated_grams REAL NOT NULL,
        FOREIGN KEY (recipe_id) REFERENCES recipes(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE daily_logs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        meal_slot TEXT NOT NULL,
        source_type TEXT NOT NULL,
        source_id INTEGER NOT NULL,
        grams_consumed REAL NOT NULL,
        water_ml REAL NOT NULL DEFAULT 0,
        morning_weight_kg REAL
      )
    ''');
    await db.execute('''
      CREATE TABLE pantry_shopping(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ingredient_id INTEGER NOT NULL,
        current_stock_g REAL NOT NULL DEFAULT 0,
        min_threshold_g REAL NOT NULL DEFAULT 0,
        to_buy_qty REAL NOT NULL DEFAULT 0,
        estimated_cost REAL NOT NULL DEFAULT 0,
        purchased_date TEXT,
        actual_price_paid REAL NOT NULL DEFAULT 0,
        FOREIGN KEY (ingredient_id) REFERENCES ingredients(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE reminders(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        schedule_type TEXT NOT NULL,
        time_or_interval TEXT NOT NULL,
        days_active TEXT NOT NULL,
        is_enabled INTEGER NOT NULL DEFAULT 1
      )
    ''');
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
