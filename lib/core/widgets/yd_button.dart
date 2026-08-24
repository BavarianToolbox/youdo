import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';

class YdButton extends StatelessWidget {
  const YdButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.variant = YdButtonVariant.primary,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final YdButtonVariant variant;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : icon != null
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon!,
              const SizedBox(width: AppSizes.sm),
              Text(label),
            ],
          )
        : Text(label);

    return switch (variant) {
      YdButtonVariant.primary => ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        child: child,
      ),
      YdButtonVariant.outline => OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        child: child,
      ),
      YdButtonVariant.ghost => TextButton(
        onPressed: isLoading ? null : onPressed,
        style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
        child: child,
      ),
      YdButtonVariant.danger => ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.penalty,
          minimumSize: const Size(double.infinity, AppSizes.buttonHeight),
        ),
        child: child,
      ),
    };
  }
}

enum YdButtonVariant { primary, outline, ghost, danger }
