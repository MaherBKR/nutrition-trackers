class ConversionService {
  /// Converts any quantity in a custom unit to grams.
  static double toGrams(double quantity, double gramEquivalent) {
    return quantity * gramEquivalent;
  }

  /// Macros for a given gram amount (macros stored per 100g).
  static Map<String, double> macrosForGrams(
    double grams,
    double calPer100g,
    double pPer100g,
    double cPer100g,
    double fPer100g,
  ) {
    final factor = grams / 100.0;
    return {
      'kcal': calPer100g * factor,
      'protein': pPer100g * factor,
      'carbs': cPer100g * factor,
      'fat': fPer100g * factor,
    };
  }

  /// Proportion of a cooked batch.
  static double batchPortionGrams(
    double servedGrams,
    double totalCookedWeightG,
  ) {
    return totalCookedWeightG == 0 ? 0 : servedGrams / totalCookedWeightG;
  }
}
