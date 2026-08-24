import 'package:equatable/equatable.dart';

enum TransactionType { reward, penalty }

enum TransactionStatus { pending, succeeded, failed }

class TransactionModel extends Equatable {
  const TransactionModel({
    required this.id,
    required this.userId,
    required this.taskId,
    required this.taskTitle,
    required this.type,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.stripeIntentId,
  });

  final String id;
  final String userId;
  final String? taskId;
  final String taskTitle;
  final TransactionType type;
  final double amount;
  final TransactionStatus status;
  final DateTime createdAt;
  final String? stripeIntentId;

  factory TransactionModel.fromJson(Map<String, dynamic> data) {
    return TransactionModel(
      id: data['id'] as String,
      userId: data['user_id'] as String,
      taskId: data['task_id'] as String?,
      taskTitle: data['task_title'] as String? ?? '',
      type: data['type'] == 'reward'
          ? TransactionType.reward
          : TransactionType.penalty,
      amount: (data['amount'] as num).toDouble(),
      status: switch (data['status'] as String? ?? 'pending') {
        'succeeded' => TransactionStatus.succeeded,
        'failed' => TransactionStatus.failed,
        _ => TransactionStatus.pending,
      },
      createdAt: DateTime.parse(data['created_at'] as String),
      stripeIntentId: data['stripe_intent_id'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, taskId, type, amount, status];
}
