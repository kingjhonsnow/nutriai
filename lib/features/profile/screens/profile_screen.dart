import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nutri_ai/core/constants/app_colors.dart';
import 'package:nutri_ai/core/constants/app_text_styles.dart';
import 'package:nutri_ai/core/services/app_exception.dart';
import 'package:nutri_ai/core/utils/calculations.dart';
import 'package:nutri_ai/core/widgets/custom_button.dart';
import 'package:nutri_ai/data/models/user_profile.dart';
import 'package:nutri_ai/features/auth/providers/auth_provider.dart';
import 'package:nutri_ai/features/goals/providers/goal_provider.dart';
import 'package:nutri_ai/features/profile/providers/profile_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingPhoto = false;

  void _snack(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: error ? AppColors.error : AppColors.success),
    );
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    final XFile? image;
    try {
      image = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
    } catch (e) {
      _snack('Could not open the ${source == ImageSource.camera ? 'camera' : 'photo library'}: ${friendlyError(e)}',
          error: true);
      return;
    }
    if (image == null) return;

    setState(() => _isUploadingPhoto = true);
    final bytes = await image.readAsBytes();
    final error = await ref.read(authProvider.notifier).updateProfilePhoto(bytes);
    if (!mounted) return;
    setState(() => _isUploadingPhoto = false);
    if (error == null) {
      _snack('Profile photo saved.');
    } else {
      _snack(error, error: true);
    }
  }

  Future<void> _removePhoto() async {
    setState(() => _isUploadingPhoto = true);
    final error = await ref.read(authProvider.notifier).removeProfilePhoto();
    if (!mounted) return;
    setState(() => _isUploadingPhoto = false);
    if (error == null) {
      _snack('Profile photo removed.');
    } else {
      _snack(error, error: true);
    }
  }

  void _showPhotoOptions(bool hasPhoto) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Profile Photo', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                title: const Text('Take a new photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadPhoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadPhoto(ImageSource.gallery);
                },
              ),
              if (hasPhoto)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                  title: const Text('Remove photo', style: TextStyle(color: AppColors.error)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _removePhoto();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditProfileDialog(UserProfile profile) {
    final nameController = TextEditingController(text: profile.name);
    final weightController = TextEditingController(text: profile.weightKg.toStringAsFixed(1));
    final heightController = TextEditingController(text: profile.heightCm.round().toString());
    final ageController = TextEditingController(text: profile.age.toString());
    var saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Update profile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(Icons.person_outline)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Weight (kg)', prefixIcon: Icon(Icons.monitor_weight_outlined)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: heightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Height (cm)', prefixIcon: Icon(Icons.height_rounded)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Age (years)', prefixIcon: Icon(Icons.cake_outlined)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: saving ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: saving
                  ? null
                  : () async {
                      final weight = double.tryParse(weightController.text.replaceAll(',', '.').trim());
                      final height = double.tryParse(heightController.text.replaceAll(',', '.').trim());
                      final age = int.tryParse(ageController.text.trim());
                      final name = nameController.text.trim();
                      if (weight == null || weight <= 20 || weight >= 500 ||
                          height == null || height <= 50 || height >= 300 ||
                          age == null || age < 10 || age > 120 || name.isEmpty) {
                        _snack('Please check the values (name, weight 20 to 500 kg, height 50 to 300 cm, age 10 to 120).',
                            error: true);
                        return;
                      }
                      setDialogState(() => saving = true);
                      try {
                        await ref.read(profileProvider.notifier).updateProfile(
                              name: name,
                              weightKg: weight,
                              heightCm: height,
                              age: age,
                            );
                        await ref.read(goalProvider.notifier).recalculate();
                        if (ctx.mounted) Navigator.pop(ctx);
                        _snack('Profile and targets updated.');
                      } catch (e) {
                        setDialogState(() => saving = false);
                        _snack(friendlyError(e), error: true);
                      }
                    },
              child: Text(saving ? 'Saving...' : 'Save & recalculate'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final profile = ref.watch(profileProvider);
    final goal = ref.watch(goalProvider);
    final avatarUrl = authState.avatarUrl;
    final hasPhoto = avatarUrl != null && avatarUrl.isNotEmpty;

    if (profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final dailyCalories = goal?.targetCalories.toDouble() ?? profile.tdee;
    final proteinG = goal?.targetProtein.toDouble() ?? 0;
    final carbsG = goal?.targetCarbs.toDouble() ?? 0;
    final fatG = goal?.targetFat.toDouble() ?? 0;
    final macroKcal = proteinG * 4 + carbsG * 4 + fatG * 9;
    double share(double kcal) => macroKcal > 0 ? (kcal / macroKcal).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded),
            tooltip: 'Update profile',
            onPressed: () => _showEditProfileDialog(profile),
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _isUploadingPhoto ? null : () => _showPhotoOptions(hasPhoto),
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: AppColors.surfaceLight,
                            backgroundImage: hasPhoto ? NetworkImage(avatarUrl!) : null,
                            child: hasPhoto
                                ? null
                                : const Icon(Icons.person_rounded, size: 50, color: AppColors.primary),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                              child: _isUploadingPhoto
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      profile.name,
                      style: AppTextStyles.headlineSmall.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      authState.userEmail ?? profile.email,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    if (goal != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                        ),
                        child: Text(
                          goal.displayName.toUpperCase(),
                          style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard('BMI', profile.bmi.toStringAsFixed(1),
                        NutritionCalculator.getBMICategory(profile.bmi), AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _buildMetricCard('BMR', '${profile.bmr.round()} kcal', 'Mifflin-St Jeor', Colors.amber)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildMetricCard('TDEE', '${profile.tdee.round()} kcal', 'Daily expenditure', Colors.orange)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard('Target', '${dailyCalories.round()} kcal', 'Goal calorie target', AppColors.success),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard('Weight', '${profile.weightKg.toStringAsFixed(1)} kg', 'Current', AppColors.accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard('Height', '${profile.heightCm.round()} cm', 'Age ${profile.age}', AppColors.accent),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (goal != null)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Daily Nutrition Plan', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      _buildMacroRow('Protein', '${proteinG.round()}g', share(proteinG * 4), AppColors.protein),
                      const SizedBox(height: 12),
                      _buildMacroRow('Carbohydrates', '${carbsG.round()}g', share(carbsG * 4), AppColors.carbs),
                      const SizedBox(height: 12),
                      _buildMacroRow('Fats', '${fatG.round()}g', share(fatG * 9), AppColors.fat),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              CustomButton(
                text: 'Update Fitness Goal',
                icon: Icons.flag_rounded,
                isOutlined: true,
                onPressed: () => context.push('/goal-selection'),
              ),
              if (authState.isAdmin) ...[
                const SizedBox(height: 12),
                CustomButton(
                  text: 'Admin: manage access',
                  icon: Icons.admin_panel_settings_rounded,
                  isOutlined: true,
                  onPressed: () => context.push('/admin'),
                ),
              ],
              const SizedBox(height: 12),
              CustomButton(
                text: 'Sign Out',
                icon: Icons.logout_rounded,
                isOutlined: true,
                onPressed: () => ref.read(authProvider.notifier).logout(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textTertiary)),
          const SizedBox(height: 6),
          Text(value, style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(subtitle, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildMacroRow(String label, String value, double percent, Color color) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTextStyles.bodyMedium),
            Text(value, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 6,
            backgroundColor: AppColors.surfaceLight,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}
