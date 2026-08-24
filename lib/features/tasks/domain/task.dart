import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';
import 'task_status.dart';

class Task extends Equatable {
  const Task({
    required this.id,
    required this.userId,
    required this.title,
    required this.dueDate,
    this.description,
    this.rewardAmount = 0.0,
    this.penaltyAmount = 0.0,
    this.status = TaskStatus.pending,
    required this.createdAt,
    this.completedAt,
    this.deadlineProcessed = false,
    this.notificationScheduled = false,
    this.stripePaymentIntentId,
  });

  final String id;
  final String userId;
  final String title;
  final String? description;
  final DateTime dueDate;
  final double rewardAmount;
  final double penaltyAmount;
  final TaskStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final bool deadlineProcessed;
  final bool notificationScheduled;
  final String? stripePaymentIntentId;

  bool get hasReward => rewardAmount > 0;
  bool get hasPenalty => penaltyAmount > 0;
  bool get hasStake => hasReward || hasPenalty;
  bool get isOverdue => status.isPending && dueDate.isBefore(DateTime.now());

  factory Task.create({
    required String userId,
    required String title,
    required DateTime dueDate,
    String? description,
    double rewardAmount = 0.0,
    double penaltyAmount = 0.0,
  }) {
    return Task(
      id: const Uuid().v4(),
      userId: userId,
      title: title,
      description: description,
      dueDate: dueDate,
      rewardAmount: rewardAmount,
      penaltyAmount: penaltyAmount,
      createdAt: DateTime.now(),
    );
  }

  factory Task.fromJson(Map<String, dynamic> data) {
    return Task(
      id: data['id'] as String,
      userId: data['user_id'] as String,
      title: data['title'] as String,
      description: data['description'] as String?,
      dueDate: DateTime.parse(data['due_date'] as String),
      rewardAmount: (data['reward_amount'] as num?)?.toDouble() ?? 0.0,
      penaltyAmount: (data['penalty_amount'] as num?)?.toDouble() ?? 0.0,
      status: TaskStatus.fromDatabaseValue(
        data['status'] as String? ?? 'pending',
      ),
      createdAt: DateTime.parse(data['created_at'] as String),
      completedAt: data['completed_at'] != null
          ? DateTime.parse(data['completed_at'] as String)
          : null,
      deadlineProcessed: data['deadline_processed'] as bool? ?? false,
      notificationScheduled: data['notification_scheduled'] as bool? ?? false,
      stripePaymentIntentId: data['stripe_payment_intent_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      if (description != null) 'description': description,
      'due_date': dueDate.toUtc().toIso8601String(),
      'reward_amount': rewardAmount,
      'penalty_amount': penaltyAmount,
      'status': status.databaseValue,
      'created_at': createdAt.toUtc().toIso8601String(),
      if (completedAt != null)
        'completed_at': completedAt!.toUtc().toIso8601String(),
      'deadline_processed': deadlineProcessed,
      'notification_scheduled': notificationScheduled,
      if (stripePaymentIntentId != null)
        'stripe_payment_intent_id': stripePaymentIntentId,
    };
  }

  Task copyWith({
    String? title,
    String? description,
    DateTime? dueDate,
    double? rewardAmount,
    double? penaltyAmount,
    TaskStatus? status,
    DateTime? completedAt,
    bool? deadlineProcessed,
    bool? notificationScheduled,
    String? stripePaymentIntentId,
  }) {
    return Task(
      id: id,
      userId: userId,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      rewardAmount: rewardAmount ?? this.rewardAmount,
      penaltyAmount: penaltyAmount ?? this.penaltyAmount,
      status: status ?? this.status,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
      deadlineProcessed: deadlineProcessed ?? this.deadlineProcessed,
      notificationScheduled:
          notificationScheduled ?? this.notificationScheduled,
      stripePaymentIntentId:
          stripePaymentIntentId ?? this.stripePaymentIntentId,
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    title,
    dueDate,
    status,
    rewardAmount,
    penaltyAmount,
  ];
}
