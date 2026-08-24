import 'package:cloud_firestore/cloud_firestore.dart';
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
  final String taskId;
  final String taskTitle;
  final TransactionType type;
  final double amount;
  final TransactionStatus status;
  final DateTime createdAt;
  final String? stripeIntentId;

  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TransactionModel(
      id: doc.id,
      userId: data['userId'] as String,
      taskId: data['taskId'] as String,
      taskTitle: data['taskTitle'] as String? ?? '',
      type: data['type'] == 'reward'
          ? TransactionType.reward
          : TransactionType.penalty,
      amount: (data['amount'] as num).toDouble(),
      status: switch (data['status'] as String? ?? 'pending') {
        'succeeded' => TransactionStatus.succeeded,
        'failed' => TransactionStatus.failed,
        _ => TransactionStatus.pending,
      },
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      stripeIntentId: data['stripeIntentId'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, taskId, type, amount, status];
}
