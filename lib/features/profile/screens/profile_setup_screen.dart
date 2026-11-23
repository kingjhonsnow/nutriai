import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nutri_ai/core/constants/app_colors.dart';
import 'package:nutri_ai/core/constants/app_text_styles.dart';
import 'package:nutri_ai/core/widgets/custom_button.dart';
import 'package:nutri_ai/core/widgets/custom_text_field.dart';
import 'package:nutri_ai/core/utils/calculations.dart';
import 'package:nutri_ai/core/utils/validators.dart';
import 'package:nutri_ai/data/models/user_profile.dart';
import 'package:nutri_ai/core/services/app_exception.dart';
import 'package:nutri_ai/features/auth/providers/auth_provider.dart';
import 'package:nutri_ai/features/profile/providers/profile_provider.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  int _currentStep = 0;

  Gender _gender = Gender.male;
  final _nameController = TextEditingController(text: 'Athlete');
  final _ageController = TextEditingController(text: '26');
  final _heightController = TextEditingController(text: '178');
  final _weightController = TextEditingController(text: '76');
  final _bodyFatController = TextEditingController(text: '16');

  ActivityLevel _activityLevel = ActivityLevel.moderatelyActive;
  String _trainingExp = 'Intermediate';
  int _weeklyWorkouts = 4;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = ref.read(profileProvider);
    if (existing != null) {
      _gender = existing.gender;
      _nameController.text = existing.name;
      _ageController.text = existing.age.toString();
      _heightController.text = existing.heightCm.round().toString();
      _weightController.text = existing.weightKg.round().toString();
      if (existing.bodyFatPercentage != null) {
        _bodyFatController.text = existing.bodyFatPercentage!.round().toString();
      }
      _activityLevel = existing.activityLevel;
      _trainingExp = existing.trainingExperience;
      _weeklyWorkouts = existing.weeklyWorkoutFrequency;
    } else {
      final accountName = ref.read(authProvider).userName;
      if (accountName != null && accountName.trim().isNotEmpty) {
        _nameController.text = accountName;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _bodyFatController.dispose();
    super.dispose();
  }

  double get _height => double.tryParse(_heightController.text.trim()) ?? 175.0;
  double get _weight => double.tryParse(_weightController.text.trim()) ?? 75.0;
  int get _age => int.tryParse(_ageController.text.trim()) ?? 25;
  double? get _bodyFat => double.tryParse(_bodyFatController.text.trim());

  double get _bmi => NutritionCalculator.calculateBMI(_weight, _height);
  double get _bmr => NutritionCalculator.calculateBMR(
        weightKg: _weight,
        heightCm: _height,
        age: _age,
        gender: _gender,
      );
  double get _tdee => NutritionCalculator.calculateTDEE(
        bmr: _bmr,
        activityLevel: _activityLevel,
      );

  String? _rangeError() {
    if (_age < 10 || _age > 120) return 'Age must be between 10 and 120.';
    if (_height <= 50 || _height >= 300) return 'Height must be between 50 and 300 cm.';
    if (_weight <= 20 || _weight >= 500) return 'Weight must be between 20 and 500 kg.';
    final bf = _bodyFat;
    if (bf != null && (bf < 2 || bf > 70)) return 'Body fat must be between 2 and 70 %.';
    return null;
  }

  Future<void> _saveAndProceed() async {
    final rangeError = _rangeError();
    if (rangeError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(rangeError), backgroundColor: AppColors.error),
      );
      return;
    }

    final auth = ref.read(authProvider);
    final profile = UserProfile.create(
      id: auth.userId ?? '',
      name: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : (auth.userName ?? 'Athlete'),
      email: auth.userEmail ?? '',
      gender: _gender,
      age: _age,
      heightCm: _height,
      weightKg: _weight,
      activityLevel: _activityLevel,
      bodyFatPercentage: _bodyFat,
      trainingExperience: _trainingExp,
      weeklyWorkoutFrequency: _weeklyWorkouts,
    );

    setState(() => _saving = true);
    try {
      await ref.read(profileProvider.notifier).saveProfile(profile);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e)), backgroundColor: AppColors.error),
        );
      }
      return;
    }
    if (mounted) {
      setState(() => _saving = false);
      context.go('/goal-selection');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Body Profile'),
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => setState(() => _currentStep--),
              )
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Bar
            LinearProgressIndicator(
              value: (_currentStep + 1) / 4,
              backgroundColor: AppColors.surfaceLight,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 4,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: _buildCurrentStep(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: CustomButton(
                text: _currentStep == 3 ? 'Confirm & Choose Goal' : 'Continue',
                isLoading: _saving,
                onPressed: () {
                  if (_currentStep < 3) {
                    setState(() => _currentStep++);
                  } else {
                    _saveAndProceed();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildStep0GenderAndAge();
      case 1:
        return _buildStep1HeightAndWeight();
      case 2:
        return _buildStep2Activity();
      case 3:
        return _buildStep3Results();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStep0GenderAndAge() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tell us about yourself',
          style: AppTextStyles.headlineLarge.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'This data powers your Mifflin-St Jeor metabolic calculations.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 28),
        CustomTextField(
          controller: _nameController,
          label: 'Your Name / Nickname',
          hint: 'e.g. Sami',
          prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.textTertiary),
        ),
        const SizedBox(height: 24),
        Text(
          'Biological Gender',
          style: AppTextStyles.labelMedium.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildGenderCard(
                gender: Gender.male,
                title: 'Male',
                icon: Icons.male_rounded,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildGenderCard(
                gender: Gender.female,
                title: 'Female',
                icon: Icons.female_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        CustomTextField(
          controller: _ageController,
          label: 'Age (years)',
          hint: '26',
          keyboardType: TextInputType.number,
          prefixIcon: const Icon(Icons.cake_outlined, color: AppColors.textTertiary),
          validator: Validators.age,
        ),
      ],
    );
  }

  Widget _buildGenderCard({
    required Gender gender,
    required String title,
    required IconData icon,
  }) {
    final isSelected = _gender == gender;
    return GestureDetector(
      onTap: () => setState(() => _gender = gender),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySurface : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.surfaceBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 40,
              color: isSelected ? AppColors.primary : AppColors.textTertiary,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: AppTextStyles.titleMedium.copyWith(
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1HeightAndWeight() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Measurements',
          style: AppTextStyles.headlineLarge.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Used to compute your BMI, base metabolic rate and energy burn.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 28),
        CustomTextField(
          controller: _heightController,
          label: 'Height (cm)',
          hint: '178',
          keyboardType: TextInputType.number,
          prefixIcon: const Icon(Icons.height_rounded, color: AppColors.textTertiary),
          validator: Validators.height,
        ),
        const SizedBox(height: 20),
        CustomTextField(
          controller: _weightController,
          label: 'Current Weight (kg)',
          hint: '76',
          keyboardType: TextInputType.number,
          prefixIcon: const Icon(Icons.monitor_weight_outlined, color: AppColors.textTertiary),
          validator: Validators.weight,
        ),
        const SizedBox(height: 20),
        CustomTextField(
          controller: _bodyFatController,
          label: 'Body Fat % (Optional)',
          hint: 'e.g. 15',
          keyboardType: TextInputType.number,
          prefixIcon: const Icon(Icons.percent_rounded, color: AppColors.textTertiary),
        ),
      ],
    );
  }

  Widget _buildStep2Activity() {
    final levels = [
      {
        'level': ActivityLevel.sedentary,
        'title': 'Sedentary',
        'desc': 'Little or no exercise, desk job (x1.2)',
      },
      {
        'level': ActivityLevel.lightlyActive,
        'title': 'Lightly Active',
        'desc': 'Light exercise 1-3 days/week (x1.375)',
      },
      {
        'level': ActivityLevel.moderatelyActive,
        'title': 'Moderately Active',
        'desc': 'Moderate training 3-5 days/week (x1.55)',
      },
      {
        'level': ActivityLevel.veryActive,
        'title': 'Very Active',
        'desc': 'Hard training 6-7 days/week (x1.725)',
      },
      {
        'level': ActivityLevel.extremelyActive,
        'title': 'Extremely Active',
        'desc': 'Physical job & intense athletics (x1.9)',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daily Activity Level',
          style: AppTextStyles.headlineLarge.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Select the option that best reflects your weekly movement.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),
        ...levels.map((item) {
          final level = item['level'] as ActivityLevel;
          final isSelected = _activityLevel == level;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: GestureDetector(
              onTap: () => setState(() => _activityLevel = level),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primarySurface : AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.surfaceBorder,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                      color: isSelected ? AppColors.primary : AppColors.textTertiary,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['title'] as String,
                            style: AppTextStyles.titleMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isSelected ? AppColors.primary : AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            item['desc'] as String,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStep3Results() {
    final bmiCategory = NutritionCalculator.getBMICategory(_bmi);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Metabolic Profile',
          style: AppTextStyles.headlineLarge.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Calculated using scientifically recognized Mifflin-St Jeor equations.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        // BMI Card
        _buildStatCard(
          title: 'Body Mass Index (BMI)',
          value: _bmi.toStringAsFixed(1),
          badge: bmiCategory,
          badgeColor: _bmi >= 18.5 && _bmi <= 24.9 ? AppColors.success : AppColors.warning,
          description: 'Normal range is 18.5 to 24.9',
          icon: Icons.speed_rounded,
        ),
        const SizedBox(height: 14),
        // BMR Card
        _buildStatCard(
          title: 'Basal Metabolic Rate (BMR)',
          value: '${_bmr.round()} kcal',
          badge: 'Base Burn',
          badgeColor: AppColors.accent,
          description: 'Calories your body burns completely at rest.',
          icon: Icons.local_fire_department_rounded,
        ),
        const SizedBox(height: 14),
        // TDEE Card
        _buildStatCard(
          title: 'Daily Energy Expenditure (TDEE)',
          value: '${_tdee.round()} kcal',
          badge: 'Maintenance',
          badgeColor: AppColors.primary,
          description: 'Calories needed daily to maintain your current weight.',
          icon: Icons.bolt_rounded,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String badge,
    required Color badgeColor,
    required String description,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: badgeColor, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: badgeColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: AppTextStyles.headlineLarge.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
