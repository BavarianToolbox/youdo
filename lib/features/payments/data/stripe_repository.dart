import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/auth_repository.dart';

class StripeRepository {
  StripeRepository(this._client);

  final SupabaseClient _client;

  Future<String> createSetupIntent() async {
    final result = await _client.functions.invoke('create-setup-intent');
    return (result.data as Map<String, dynamic>)['clientSecret'] as String;
  }

  Future<void> confirmSetupIntent(String clientSecret) async {
    await Stripe.instance.confirmSetupIntent(
      paymentIntentClientSecret: clientSecret,
      params: const PaymentMethodParams.card(
        paymentMethodData: PaymentMethodData(),
      ),
    );
  }

  Future<Map<String, dynamic>> savePaymentMethod(String paymentMethodId) async {
    final result = await _client.functions.invoke(
      'save-payment-method',
      body: {'paymentMethodId': paymentMethodId},
    );
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<Map<String, dynamic>> processTaskCompletion({
    required String taskId,
  }) async {
    final result = await _client.functions.invoke(
      'process-task-completion',
      body: {'taskId': taskId},
    );
    return Map<String, dynamic>.from(result.data as Map);
  }
}

final stripeRepositoryProvider = Provider<StripeRepository>((ref) {
  return StripeRepository(ref.watch(supabaseClientProvider));
});
