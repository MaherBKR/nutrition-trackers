import 'package:flutter/material.dart';
import 'screens/ingredient_list_screen.dart';
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
      home: const IngredientListScreen(),
    );
  }
}
