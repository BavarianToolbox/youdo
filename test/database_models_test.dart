import 'package:flutter_test/flutter_test.dart';
import 'package:youdo/features/auth/domain/app_user.dart';
import 'package:youdo/features/history/data/transaction_model.dart';
import 'package:youdo/features/tasks/domain/task.dart';
import 'package:youdo/features/tasks/domain/task_status.dart';

void main() {
  test('AppUser reads the PostgreSQL profile shape', () {
    final user = AppUser.fromJson({
      'id': 'user-id',
      'email': 'dev@example.com',
      'display_name': 'Dev User',
      'onboarding_complete': true,
      'total_earned': 12.50,
      'total_lost': 3,
    });

    expect(user.uid, 'user-id');
    expect(user.displayName, 'Dev User');
    expect(user.onboardingComplete, isTrue);
    expect(user.totalEarned, 12.50);
    expect(user.totalLost, 3.0);
  });

  test('Task round-trips the PostgreSQL row shape', () {
    final task = Task(
      id: '00000000-0000-0000-0000-000000000001',
      userId: '00000000-0000-0000-0000-000000000002',
      title: 'Ship migration',
      dueDate: DateTime.utc(2026, 8, 25, 12),
      rewardAmount: 10,
      penaltyAmount: 5,
      status: TaskStatus.pending,
      createdAt: DateTime.utc(2026, 8, 24, 12),
    );

    final restored = Task.fromJson(task.toJson());

    expect(restored, task);
    expect(task.toJson()['due_date'], '2026-08-25T12:00:00.000Z');
    expect(task.toJson()['reward_amount'], 10);
  });

  test('Transaction accepts a deleted task reference', () {
    final transaction = TransactionModel.fromJson({
      'id': 'transaction-id',
      'user_id': 'user-id',
      'task_id': null,
      'task_title': 'Historical task',
      'type': 'penalty',
      'amount': 4.25,
      'status': 'succeeded',
      'created_at': '2026-08-24T12:00:00Z',
    });

    expect(transaction.taskId, isNull);
    expect(transaction.type, TransactionType.penalty);
    expect(transaction.status, TransactionStatus.succeeded);
  });
}
