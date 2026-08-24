import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/yd_card.dart';
import '../../domain/task.dart';
import '../../domain/task_status.dart';
import 'stake_badge.dart';

class TaskCard extends StatelessWidget {
  const TaskCard({super.key, required this.task, required this.onTap});

  final Task task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return YdCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusIndicator(status: task.status, isOverdue: task.isOverdue),
          const Gap(AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    decoration: task.status.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                    color: task.status.isCompleted
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Gap(AppSizes.xs),
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 12,
                      color: _dueDateColor,
                    ),
                    const Gap(4),
                    Text(
                      DateFormatter.formatRelative(task.dueDate),
                      style: TextStyle(
                        fontSize: 12,
                        color: _dueDateColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (task.hasStake) ...[
                  const Gap(AppSizes.sm),
                  StakeBadge(
                    rewardAmount: task.rewardAmount,
                    penaltyAmount: task.penaltyAmount,
                    compact: true,
                  ),
                ],
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textDisabled,
          ),
        ],
      ),
    );
  }

  Color get _dueDateColor {
    if (task.isOverdue) return AppColors.penalty;
    if (task.status.isCompleted) return AppColors.success;
    if (task.dueDate.difference(DateTime.now()).inHours < 2)
      return AppColors.late;
    return AppColors.textSecondary;
  }
}

class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({required this.status, required this.isOverdue});

  final TaskStatus status;
  final bool isOverdue;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      TaskStatus.completedOnTime => (
        AppColors.success,
        Icons.check_circle_rounded,
      ),
      TaskStatus.completedLate => (
        AppColors.late,
        Icons.check_circle_outline_rounded,
      ),
      TaskStatus.missed => (AppColors.penalty, Icons.cancel_rounded),
      TaskStatus.pending =>
        isOverdue
            ? (AppColors.penalty, Icons.radio_button_unchecked_rounded)
            : (AppColors.border, Icons.radio_button_unchecked_rounded),
    };

    return Icon(icon, color: color, size: AppSizes.iconMd);
  }
}
