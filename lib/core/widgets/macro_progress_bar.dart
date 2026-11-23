import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:nutri_ai/core/constants/app_colors.dart';
import 'package:nutri_ai/core/constants/app_text_styles.dart';

class MacroCircularIndicator extends StatelessWidget {
  final String label;
  final double consumed;
  final double target;
  final Color color;
  final double radius;

  const MacroCircularIndicator({
    super.key,
    required this.label,
    required this.consumed,
    required this.target,
    required this.color,
    this.radius = 42,
  });

  @override
  Widget build(BuildContext context) {
    final percent = target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0;
    final remaining = (target - consumed).clamp(0.0, 9999.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularPercentIndicator(
          radius: radius,
          lineWidth: 7.0,
          percent: percent,
          circularStrokeCap: CircularStrokeCap.round,
          backgroundColor: AppColors.surfaceLight,
          progressColor: color,
          center: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${consumed.round()}g',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '/${target.round()}g',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textTertiary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: AppTextStyles.titleSmall.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          '${remaining.round()}g left',
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textTertiary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class MacroLinearProgressBar extends StatelessWidget {
  final String label;
  final double consumed;
  final double target;
  final Color color;

  const MacroLinearProgressBar({
    super.key,
    required this.label,
    required this.consumed,
    required this.target,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final percent = target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AppTextStyles.titleSmall.copyWith(color: AppColors.textSecondary),
            ),
            Text(
              '${consumed.round()} / ${target.round()} g',
              style: AppTextStyles.titleSmall.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearPercentIndicator(
          lineHeight: 8.0,
          percent: percent,
          padding: EdgeInsets.zero,
          barRadius: const Radius.circular(4),
          backgroundColor: AppColors.surfaceLight,
          progressColor: color,
        ),
      ],
    );
  }
}
