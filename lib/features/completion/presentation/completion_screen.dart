import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/yd_button.dart';
import '../../../services/audio_service.dart';
import '../../../services/haptics_service.dart';
import '../../auth/data/auth_repository.dart';
import '../../payments/data/stripe_repository.dart';
import '../../tasks/data/tasks_repository.dart';
import '../../tasks/domain/task.dart';

class CompletionScreen extends ConsumerStatefulWidget {
  const CompletionScreen({
    super.key,
    required this.task,
    required this.isOnTime,
  });

  final Task task;
  final bool isOnTime;

  @override
  ConsumerState<CompletionScreen> createState() => _CompletionScreenState();
}

class _CompletionScreenState extends ConsumerState<CompletionScreen>
    with SingleTickerProviderStateMixin {
  late final ConfettiController _confettiController;
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;

  bool _isProcessing = true;
  String? _resultMessage;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 4),
    );
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );
    _processCompletion();
  }

  Future<void> _processCompletion() async {
    try {
      // Persist completion before processing any configured stake.
      await ref
          .read(tasksRepositoryProvider)
          .markComplete(widget.task.id, isOnTime: widget.isOnTime);

      // Process payment if stakes are configured and user has a payment method
      final user = ref.read(currentUserProvider).valueOrNull;
      if (user?.hasPaymentMethod == true && widget.task.hasStake) {
        try {
          final result = await ref
              .read(stripeRepositoryProvider)
              .processTaskCompletion(
                taskId: widget.task.id,
                isOnTime: widget.isOnTime,
              );
          _resultMessage = result['message'] as String?;
        } catch (_) {
          // Payment error — task is still marked complete, show soft error
          _resultMessage = 'Payment processing — check history for details';
        }
      }

      if (mounted) {
        setState(() => _isProcessing = false);
        _scaleController.forward();

        if (widget.isOnTime) {
          _confettiController.play();
          await ref.read(hapticsServiceProvider).successPattern();
          await ref.read(audioServiceProvider).playSuccess();
        } else {
          await ref.read(hapticsServiceProvider).lightTap();
          await ref.read(audioServiceProvider).playSoftChime();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.isOnTime
          ? AppColors.primary
          : AppColors.background,
      body: Stack(
        children: [
          if (widget.isOnTime)
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                numberOfParticles: 30,
                gravity: 0.1,
                colors: const [
                  AppColors.accent,
                  Colors.amber,
                  Colors.white,
                  Colors.pinkAccent,
                  Colors.cyanAccent,
                ],
              ),
            ),
          SafeArea(
            child: _isProcessing
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        Gap(AppSizes.md),
                        Text(
                          'Processing...',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  )
                : _hasError
                ? _ErrorBody(onDismiss: () => context.go('/tasks'))
                : ScaleTransition(
                    scale: _scaleAnimation,
                    child: _ResultBody(
                      task: widget.task,
                      isOnTime: widget.isOnTime,
                      message: _resultMessage,
                      onDone: () => context.go('/tasks'),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ResultBody extends StatelessWidget {
  const _ResultBody({
    required this.task,
    required this.isOnTime,
    required this.message,
    required this.onDone,
  });

  final Task task;
  final bool isOnTime;
  final String? message;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final textColor = isOnTime ? Colors.white : AppColors.textPrimary;
    final subColor = isOnTime ? Colors.white70 : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.all(AppSizes.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isOnTime
                ? Icons.emoji_events_rounded
                : Icons.check_circle_outline_rounded,
            size: 80,
            color: isOnTime ? Colors.amber : AppColors.success,
          ),
          const Gap(AppSizes.lg),
          Text(
            isOnTime ? AppStrings.completedOnTime : AppStrings.completedLate,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
            textAlign: TextAlign.center,
          ),
          const Gap(AppSizes.md),
          Text(
            '"${task.title}"',
            style: TextStyle(
              fontSize: 16,
              fontStyle: FontStyle.italic,
              color: subColor,
            ),
            textAlign: TextAlign.center,
          ),
          const Gap(AppSizes.lg),
          if (isOnTime && task.hasReward) ...[
            _StakeResult(
              label: 'Reward earned',
              amount: task.rewardAmount,
              color: Colors.amber,
              isOnLight: false,
            ),
          ] else if (!isOnTime && task.hasPenalty) ...[
            _StakeResult(
              label: 'Late penalty applied',
              amount: task.penaltyAmount,
              color: AppColors.penalty,
              isOnLight: !isOnTime,
            ),
          ] else if (isOnTime && task.hasPenalty) ...[
            _StakeResult(
              label: 'Penalty avoided',
              amount: task.penaltyAmount,
              color: AppColors.accent,
              isOnLight: false,
            ),
          ],
          if (message != null) ...[
            const Gap(AppSizes.md),
            Container(
              padding: const EdgeInsets.all(AppSizes.md),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              child: Text(
                message!,
                style: TextStyle(fontSize: 13, color: subColor),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const Gap(AppSizes.xxl),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onDone,
              style: ElevatedButton.styleFrom(
                backgroundColor: isOnTime ? Colors.white : AppColors.primary,
                foregroundColor: isOnTime ? AppColors.primary : Colors.white,
              ),
              child: const Text('Back to Tasks'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StakeResult extends StatelessWidget {
  const _StakeResult({
    required this.label,
    required this.amount,
    required this.color,
    required this.isOnLight,
  });

  final String label;
  final double amount;
  final Color color;
  final bool isOnLight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(isOnLight ? 0.1 : 0.2),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isOnLight ? color : Colors.white70,
            ),
          ),
          Text(
            CurrencyFormatter.format(amount),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: isOnLight ? color : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 64,
            color: AppColors.penalty,
          ),
          const Gap(AppSizes.lg),
          Text(
            AppStrings.genericError,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const Gap(AppSizes.xl),
          YdButton(label: 'Go Back', onPressed: onDismiss),
        ],
      ),
    );
  }
}
