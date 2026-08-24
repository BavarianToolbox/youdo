import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../auth/data/auth_repository.dart';
import '../data/history_repository.dart';
import '../data/transaction_model.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(transactionListProvider);
    final user = ref.watch(currentUserProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.history)),
      body: txAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Text(
            AppStrings.genericError,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        data: (transactions) {
          if (transactions.isEmpty) {
            return const _EmptyState();
          }
          final totalEarned = user?.totalEarned ?? 0.0;
          final totalLost = user?.totalLost ?? 0.0;

          return Column(
            children: [
              _SummaryBar(totalEarned: totalEarned, totalLost: totalLost),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSizes.md),
                  itemCount: transactions.length,
                  separatorBuilder: (_, __) => const Gap(AppSizes.sm),
                  itemBuilder: (ctx, i) =>
                      _TransactionTile(tx: transactions[i]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.totalEarned, required this.totalLost});

  final double totalEarned;
  final double totalLost;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      color: AppColors.surface,
      child: Row(
        children: [
          Expanded(
            child: _SummaryStat(
              label: AppStrings.totalEarned,
              value: CurrencyFormatter.format(totalEarned),
              color: AppColors.rewardGreen,
              icon: Icons.trending_up_rounded,
            ),
          ),
          Container(width: 1, height: 40, color: AppColors.border),
          Expanded(
            child: _SummaryStat(
              label: AppStrings.totalLost,
              value: CurrencyFormatter.format(totalLost),
              color: AppColors.penaltyRed,
              icon: Icons.trending_down_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const Gap(4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const Gap(4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.tx});

  final TransactionModel tx;

  @override
  Widget build(BuildContext context) {
    final isReward = tx.type == TransactionType.reward;
    final color = isReward ? AppColors.rewardGreen : AppColors.penaltyRed;
    final prefix = isReward ? '+' : '-';
    final formatted = DateFormat('MMM d, h:mm a').format(tx.createdAt);

    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
            child: Icon(
              isReward
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
              color: color,
              size: 20,
            ),
          ),
          const Gap(AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.taskTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(formatted, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$prefix${CurrencyFormatter.format(tx.amount)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              _StatusChip(status: tx.status),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final TransactionStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      TransactionStatus.succeeded => ('Completed', AppColors.success),
      TransactionStatus.failed => ('Failed', AppColors.penalty),
      TransactionStatus.pending => ('Pending', AppColors.late),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            size: 56,
            color: AppColors.textDisabled,
          ),
          const Gap(AppSizes.md),
          Text(
            AppStrings.noHistory,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
