import 'package:flutter/material.dart';
import 'screens/analytics_screen.dart';
import 'screens/daily_log_screen.dart';
import 'screens/ingredient_list_screen.dart';
import 'screens/pantry_screen.dart';
import 'screens/recipe_list_screen.dart';
import 'screens/shopping_screen.dart';
import 'services/seed_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SeedService.seedIfNeeded();
  runApp(const NutritionApp());
}

class NutritionApp extends StatelessWidget {
  const NutritionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nutrition Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  static const _screens = [
    DailyLogScreen(),
    IngredientListScreen(),
    RecipeListScreen(),
    PantryScreen(),
    ShoppingScreen(),
    AnalyticsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today), label: 'Today'),
          NavigationDestination(icon: Icon(Icons.eco), label: 'Foods'),
          NavigationDestination(icon: Icon(Icons.restaurant_menu), label: 'Recipes'),
          NavigationDestination(icon: Icon(Icons.inventory_2), label: 'Pantry'),
          NavigationDestination(icon: Icon(Icons.shopping_cart), label: 'Shop'),
          NavigationDestination(icon: Icon(Icons.insights), label: 'Stats'),
        ],
      ),
    );
  }
}
