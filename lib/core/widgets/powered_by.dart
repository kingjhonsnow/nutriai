import 'package:flutter/material.dart';
import 'package:nutri_ai/core/constants/app_colors.dart';

/// "Powered by Ahmed Ben Hassen" credit line, shown at the bottom of the
/// launch screen and the sign in / registration screens.
class PoweredBy extends StatelessWidget {
  const PoweredBy({super.key});

  static const String author = 'Ahmed Ben Hassen';

  @override
  Widget build(BuildContext context) {
    return const Text.rich(
      TextSpan(
        style: TextStyle(
          fontSize: 12,
          color: AppColors.textTertiary,
          letterSpacing: 0.3,
        ),
        children: [
          TextSpan(text: 'Powered by '),
          TextSpan(
            text: author,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
