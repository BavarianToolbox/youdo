import 'package:flutter_test/flutter_test.dart';
import 'package:youdo/features/payments/data/stripe_repository.dart';

void main() {
  late FakePaymentFunctionsGateway gateway;
  late StripeRepository repository;

  setUp(() {
    gateway = FakePaymentFunctionsGateway();
    repository = StripeRepository.gateway(gateway);
  });

  test('createSetupIntent returns the backend client secret', () async {
    gateway.response = {'clientSecret': 'seti_secret'};

    expect(await repository.createSetupIntent(), 'seti_secret');
    expect(gateway.functionName, 'create-setup-intent');
  });

  test('createSetupIntent rejects a malformed response', () async {
    gateway.response = {'unexpected': true};

    expect(
      repository.createSetupIntent(),
      throwsA(isA<PaymentResponseException>()),
    );
  });

  test(
    'savePaymentMethod forwards its identifier and requires success',
    () async {
      gateway.response = {'success': true};

      await repository.savePaymentMethod('pm_123');

      expect(gateway.functionName, 'save-payment-method');
      expect(gateway.body, {'paymentMethodId': 'pm_123'});
    },
  );

  test('savePaymentMethod rejects an unsuccessful response', () async {
    gateway.response = {'success': false};

    expect(
      repository.savePaymentMethod('pm_123'),
      throwsA(isA<PaymentResponseException>()),
    );
  });

  test('processTaskCompletion returns a typed result', () async {
    gateway.response = {'message': 'Reward recorded', 'isOnTime': true};

    final result = await repository.processTaskCompletion(taskId: 'task-1');

    expect(gateway.functionName, 'process-task-completion');
    expect(gateway.body, {'taskId': 'task-1'});
    expect(result.message, 'Reward recorded');
    expect(result.isOnTime, isTrue);
  });

  test('processTaskCompletion rejects an ambiguous response', () async {
    gateway.response = {'message': 'Maybe completed'};

    expect(
      repository.processTaskCompletion(taskId: 'task-1'),
      throwsA(isA<PaymentResponseException>()),
    );
  });

  test('backend invocation failures are propagated', () async {
    gateway.error = StateError('network unavailable');

    expect(
      repository.processTaskCompletion(taskId: 'task-1'),
      throwsA(isA<StateError>()),
    );
  });
}

class FakePaymentFunctionsGateway implements PaymentFunctionsGateway {
  Object? response;
  Object? error;
  String? functionName;
  Map<String, dynamic>? body;

  @override
  Future<Object?> invoke(
    String functionName, {
    Map<String, dynamic>? body,
  }) async {
    this.functionName = functionName;
    this.body = body;
    if (error case final error?) throw error;
    return response;
  }
}
