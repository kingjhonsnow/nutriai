class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'NutriAI';
  static const String appVersion = '1.0.0';

  // Database
  static const String databaseName = 'nutri_ai.db';
  static const int databaseVersion = 1;

  // Activity Level Multipliers (Harris-Benedict)
  static const double sedentaryMultiplier = 1.2;
  static const double lightlyActiveMultiplier = 1.375;
  static const double moderatelyActiveMultiplier = 1.55;
  static const double veryActiveMultiplier = 1.725;
  static const double extraActiveMultiplier = 1.9;

  // Macro Ratios by Goal (protein%, carbs%, fat%)
  // Bulking
  static const double bulkingProteinRatio = 0.25;
  static const double bulkingCarbsRatio = 0.50;
  static const double bulkingFatRatio = 0.25;

  // Cutting
  static const double cuttingProteinRatio = 0.40;
  static const double cuttingCarbsRatio = 0.35;
  static const double cuttingFatRatio = 0.25;

  // Maintenance
  static const double maintenanceProteinRatio = 0.30;
  static const double maintenanceCarbsRatio = 0.40;
  static const double maintenanceFatRatio = 0.30;

  // Calorie Adjustments
  static const int bulkingSurplusCalories = 500;
  static const int cuttingDeficitCalories = 500;
  static const int aggressiveCuttingDeficitCalories = 750;
  static const int leanBulkingSurplusCalories = 250;

  // Calorie per gram
  static const double caloriesPerGramProtein = 4.0;
  static const double caloriesPerGramCarbs = 4.0;
  static const double caloriesPerGramFat = 9.0;
  static const double caloriesPerGramFiber = 2.0;
  static const double caloriesPerGramAlcohol = 7.0;

  // Water
  static const double dailyWaterGoalMl = 2500.0;
  static const double waterPerKgBodyWeight = 35.0;

  // Weight Change Rates (kg per week)
  static const double safeCuttingRate = 0.5;
  static const double aggressiveCuttingRate = 1.0;
  static const double safeBulkingRate = 0.25;
  static const double aggressiveBulkingRate = 0.5;

  // BMI Categories
  static const double bmiUnderweight = 18.5;
  static const double bmiNormal = 24.9;
  static const double bmiOverweight = 29.9;
  static const double bmiObese = 34.9;
  static const double bmiSeverelyObese = 39.9;

  // Nutrient RDA (Recommended Daily Allowance)
  static const double rdaFiberMale = 38.0;
  static const double rdaFiberFemale = 25.0;
  static const double rdaSugarMax = 50.0;
  static const double rdaSodiumMax = 2300.0;
  static const double rdaPotassium = 2600.0;
  static const double rdaCalcium = 1000.0;
  static const double rdaIron = 18.0;
  static const double rdaVitaminC = 90.0;
  static const double rdaVitaminD = 20.0;

  // Meal Types
  static const String mealBreakfast = 'breakfast';
  static const String mealLunch = 'lunch';
  static const String mealDinner = 'dinner';
  static const String mealSnack = 'snack';

  // Shared Preferences Keys
  static const String prefIsFirstLaunch = 'is_first_launch';
  static const String prefIsLoggedIn = 'is_logged_in';
  static const String prefUserId = 'user_id';
  static const String prefThemeMode = 'theme_mode';
  static const String prefDailyCalorieGoal = 'daily_calorie_goal';
  static const String prefDailyWaterGoal = 'daily_water_goal';
  static const String prefNotificationsEnabled = 'notifications_enabled';
  static const String prefMealReminders = 'meal_reminders';
  static const String prefWeightUnit = 'weight_unit';
  static const String prefHeightUnit = 'height_unit';
  static const String prefOnboardingComplete = 'onboarding_complete';

  // Animation Durations
  static const Duration animFast = Duration(milliseconds: 200);
  static const Duration animMedium = Duration(milliseconds: 400);
  static const Duration animSlow = Duration(milliseconds: 800);
  static const Duration animVerySlow = Duration(milliseconds: 1200);

  // Pagination
  static const int defaultPageSize = 20;
  static const int searchDebounceMs = 300;

  // Validation
  static const int minAge = 13;
  static const int maxAge = 120;
  static const double minWeightKg = 20.0;
  static const double maxWeightKg = 300.0;
  static const double minHeightCm = 100.0;
  static const double maxHeightCm = 250.0;
  static const int maxNameLength = 50;
  static const int maxNotesLength = 500;
}
