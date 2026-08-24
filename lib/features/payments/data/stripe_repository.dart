import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

class StripeRepository {
  StripeRepository(this._functions);

  final FirebaseFunctions _functions;

  Future<String> createSetupIntent() async {
    final result = await _functions.httpsCallable('createSetupIntent').call();
    return result.data['clientSecret'] as String;
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
    final result = await _functions.httpsCallable('savePaymentMethod').call({
      'paymentMethodId': paymentMethodId,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<Map<String, dynamic>> processTaskCompletion({
    required String taskId,
    required bool isOnTime,
  }) async {
    final result = await _functions.httpsCallable('processTaskCompletion').call(
      {'taskId': taskId, 'isOnTime': isOnTime},
    );
    return Map<String, dynamic>.from(result.data as Map);
  }
}

final stripeRepositoryProvider = Provider<StripeRepository>((ref) {
  return StripeRepository(FirebaseFunctions.instance);
});
