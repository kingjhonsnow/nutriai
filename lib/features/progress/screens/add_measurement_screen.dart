import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutri_ai/core/constants/app_colors.dart';
import 'package:nutri_ai/core/constants/app_text_styles.dart';
import 'package:nutri_ai/core/widgets/custom_button.dart';
import 'package:nutri_ai/core/widgets/custom_text_field.dart';
import 'package:nutri_ai/core/utils/validators.dart';
import 'package:nutri_ai/data/models/progress_entry.dart';
import 'package:nutri_ai/features/progress/providers/progress_provider.dart';
import 'package:nutri_ai/core/services/app_exception.dart';
import 'package:nutri_ai/core/utils/extensions.dart';
import 'package:nutri_ai/features/goals/providers/goal_provider.dart';
import 'package:nutri_ai/features/profile/providers/profile_provider.dart';

class AddMeasurementScreen extends ConsumerStatefulWidget {
  const AddMeasurementScreen({super.key});

  @override
  ConsumerState<AddMeasurementScreen> createState() => _AddMeasurementScreenState();
}

class _AddMeasurementScreenState extends ConsumerState<AddMeasurementScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  final _weightController = TextEditingController();
  final _bodyFatController = TextEditingController();
  final _waistController = TextEditingController();
  final _chestController = TextEditingController();
  final _armsController = TextEditingController();
  final _legsController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _weightController.dispose();
    _bodyFatController.dispose();
    _waistController.dispose();
    _chestController.dispose();
    _armsController.dispose();
    _legsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveMeasurement() async {
    if (!_formKey.currentState!.validate()) return;

    double? parse(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.').trim());
    final weight = parse(_weightController);
    if (weight == null || weight <= 20 || weight >= 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a weight between 20 and 500 kg.'), backgroundColor: AppColors.error),
      );
      return;
    }
    final bf = parse(_bodyFatController);
    final waist = parse(_waistController);
    final chest = parse(_chestController);
    final arms = parse(_armsController);
    final legs = parse(_legsController);

    final entry = ProgressEntry(
      id: 'entry_${DateTime.now().millisecondsSinceEpoch}',
      date: _selectedDate,
      weightKg: weight,
      bodyFatPercentage: bf,
      measurements: BodyMeasurements(
        waistCm: waist,
        chestCm: chest,
        armsCm: arms,
        legsCm: legs,
      ),
      notes: _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
    );

    setState(() => _saving = true);
    try {
      await ref.read(progressProvider.notifier).addEntry(entry);
      if (entry.date.isSameDay(DateTime.now())) {
        // Keep the profile weight (and the calorie targets) up to date.
        await ref.read(profileProvider.notifier).updateProfile(weightKg: weight);
        await ref.read(goalProvider.notifier).recalculate();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e)), backgroundColor: AppColors.error),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Measurement saved.'),
        backgroundColor: AppColors.success,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Log Body Progress'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Record Today\'s Stats',
                  style: AppTextStyles.headlineSmall.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Log your body measurements to monitor transformation over time.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),

                // Weight & Body Fat
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: _weightController,
                        label: 'Weight (kg) *',
                        hint: '75.5',
                        keyboardType: TextInputType.number,
                        validator: Validators.weight,
                        prefixIcon: const Icon(Icons.monitor_weight_outlined,
                            color: AppColors.textTertiary),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomTextField(
                        controller: _bodyFatController,
                        label: 'Body Fat %',
                        hint: '15.5',
                        keyboardType: TextInputType.number,
                        prefixIcon: const Icon(Icons.percent_rounded,
                            color: AppColors.textTertiary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Text(
                  'Circumference Measurements (cm)',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: _waistController,
                        label: 'Waist',
                        hint: '82 cm',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: CustomTextField(
                        controller: _chestController,
                        label: 'Chest',
                        hint: '102 cm',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: _armsController,
                        label: 'Arms (Flexed)',
                        hint: '37 cm',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: CustomTextField(
                        controller: _legsController,
                        label: 'Thighs / Legs',
                        hint: '57 cm',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                CustomTextField(
                  controller: _notesController,
                  label: 'Notes / Workout Reflections',
                  hint: 'e.g. Completed heavy bench workout, good hydration',
                  maxLines: 2,
                ),
                const SizedBox(height: 32),

                CustomButton(
                  text: 'Save Progress Entry',
                  icon: Icons.check_circle_rounded,
                  isLoading: _saving,
                  onPressed: _saveMeasurement,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
