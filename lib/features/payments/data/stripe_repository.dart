import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/auth_repository.dart';

abstract interface class PaymentFunctionsGateway {
  Future<Object?> invoke(String functionName, {Map<String, dynamic>? body});
}

class SupabasePaymentFunctionsGateway implements PaymentFunctionsGateway {
  SupabasePaymentFunctionsGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<Object?> invoke(
    String functionName, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _client.functions.invoke(functionName, body: body);
    return response.data;
  }
}

class PaymentResponseException implements Exception {
  const PaymentResponseException(this.message);

  final String message;

  @override
  String toString() => 'PaymentResponseException: $message';
}

class TaskCompletionResult {
  const TaskCompletionResult({required this.message, required this.isOnTime});

  final String message;
  final bool isOnTime;
}

class StripeRepository {
  StripeRepository(SupabaseClient client)
    : this.gateway(SupabasePaymentFunctionsGateway(client));

  StripeRepository.gateway(this._gateway);

  final PaymentFunctionsGateway _gateway;

  Future<String> createSetupIntent() async {
    final data = _asMap(await _gateway.invoke('create-setup-intent'));
    final clientSecret = data['clientSecret'];
    if (clientSecret is! String || clientSecret.isEmpty) {
      throw const PaymentResponseException(
        'create-setup-intent did not return a clientSecret',
      );
    }
    return clientSecret;
  }

  Future<void> savePaymentMethod(String paymentMethodId) async {
    final data = _asMap(
      await _gateway.invoke(
        'save-payment-method',
        body: {'paymentMethodId': paymentMethodId},
      ),
    );
    if (data['success'] != true) {
      throw const PaymentResponseException(
        'save-payment-method did not report success',
      );
    }
  }

  Future<TaskCompletionResult> processTaskCompletion({
    required String taskId,
  }) async {
    final data = _asMap(
      await _gateway.invoke(
        'process-task-completion',
        body: {'taskId': taskId},
      ),
    );
    final message = data['message'];
    final isOnTime = data['isOnTime'];
    if (message is! String || isOnTime is! bool) {
      throw const PaymentResponseException(
        'process-task-completion returned an invalid response',
      );
    }
    return TaskCompletionResult(message: message, isOnTime: isOnTime);
  }

  Map<String, dynamic> _asMap(Object? data) {
    if (data is! Map) {
      throw const PaymentResponseException(
        'Backend returned a non-map response',
      );
    }
    return Map<String, dynamic>.from(data);
  }
}

final stripeRepositoryProvider = Provider<StripeRepository>((ref) {
  return StripeRepository(ref.watch(supabaseClientProvider));
});
