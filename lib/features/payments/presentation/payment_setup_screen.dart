import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:gap/gap.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/yd_button.dart';
import '../../auth/data/auth_repository.dart';
import '../data/stripe_repository.dart';

class PaymentSetupScreen extends ConsumerStatefulWidget {
  const PaymentSetupScreen({super.key, this.isOnboarding = false});

  final bool isOnboarding;

  @override
  ConsumerState<PaymentSetupScreen> createState() => _PaymentSetupScreenState();
}

class _PaymentSetupScreenState extends ConsumerState<PaymentSetupScreen> {
  CardFieldInputDetails? _cardDetails;
  bool _isLoading = false;
  String? _error;

  Future<void> _saveCard() async {
    if (_cardDetails?.complete != true) {
      setState(() => _error = 'Please enter complete card details.');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(stripeRepositoryProvider);

      // 1. Get SetupIntent client secret from backend
      final clientSecret = await repo.createSetupIntent();

      // 2. Confirm SetupIntent on-device (Stripe SDK handles PCI compliance)
      final result = await Stripe.instance.confirmSetupIntent(
        paymentIntentClientSecret: clientSecret,
        params: const PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(),
        ),
      );

      // 3. Save the payment method ID on the backend
      await repo.savePaymentMethod(result.paymentMethodId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Card saved successfully!')),
        );
        Navigator.of(context).pop(true);
      }
    } on StripeException catch (e) {
      setState(
        () => _error = e.error.localizedMessage ?? AppStrings.paymentError,
      );
    } catch (e) {
      setState(() => _error = AppStrings.paymentError);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final hasCard = user?.hasPaymentMethod == true;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.paymentMethod)),
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasCard) ...[
              Container(
                padding: const EdgeInsets.all(AppSizes.md),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.credit_card_rounded,
                      color: AppColors.primary,
                    ),
                    const Gap(AppSizes.md),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current payment method',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          'Card on file',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.success,
                    ),
                  ],
                ),
              ),
              const Gap(AppSizes.lg),
              Text(
                'Replace card',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Gap(AppSizes.sm),
            ] else ...[
              Text(
                AppStrings.addPaymentMethod,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Gap(AppSizes.sm),
              Text(
                'Your card is stored securely by Stripe. You-Do never sees your full card number.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Gap(AppSizes.lg),
            ],
            CardField(
              onCardChanged: (details) =>
                  setState(() => _cardDetails = details),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 2,
                  ),
                ),
              ),
            ),
            if (_error != null) ...[
              const Gap(AppSizes.sm),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.penalty, fontSize: 13),
              ),
            ],
            const Gap(AppSizes.lg),
            YdButton(
              label: AppStrings.saveCard,
              onPressed: _saveCard,
              isLoading: _isLoading,
            ),
            if (widget.isOnboarding) ...[
              const Gap(AppSizes.md),
              YdButton(
                label: AppStrings.skipForNow,
                onPressed: () => Navigator.of(context).pop(false),
                variant: YdButtonVariant.ghost,
              ),
            ],
            const Gap(AppSizes.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 14,
                  color: AppColors.textDisabled,
                ),
                const Gap(4),
                Text(
                  'Secured by Stripe',
                  style: TextStyle(fontSize: 12, color: AppColors.textDisabled),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
