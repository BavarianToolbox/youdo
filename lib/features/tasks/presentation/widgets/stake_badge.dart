import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/currency_formatter.dart';

class StakeBadge extends StatelessWidget {
  const StakeBadge({
    super.key,
    this.rewardAmount = 0,
    this.penaltyAmount = 0,
    this.compact = false,
  });

  final double rewardAmount;
  final double penaltyAmount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final hasReward = rewardAmount > 0;
    final hasPenalty = penaltyAmount > 0;

    if (!hasReward && !hasPenalty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasReward) ...[
          _Badge(
            label: compact
                ? CurrencyFormatter.formatCompact(rewardAmount)
                : '+${CurrencyFormatter.formatCompact(rewardAmount)}',
            color: AppColors.rewardGreen,
            icon: Icons.trending_up_rounded,
          ),
        ],
        if (hasReward && hasPenalty) const Gap(AppSizes.xs),
        if (hasPenalty) ...[
          _Badge(
            label: compact
                ? CurrencyFormatter.formatCompact(penaltyAmount)
                : '-${CurrencyFormatter.formatCompact(penaltyAmount)}',
            color: AppColors.penaltyRed,
            icon: Icons.trending_down_rounded,
          ),
        ],
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color, required this.icon});

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sm,
        vertical: AppSizes.xs,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const Gap(2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
