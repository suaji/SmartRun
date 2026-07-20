
class CalorieCalculator {
  CalorieCalculator._();

  static double estimate({required double weightKg, required double distanceKm}) {
    return weightKg * distanceKm * 1.036;
  }
}
