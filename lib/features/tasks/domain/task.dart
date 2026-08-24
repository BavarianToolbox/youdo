import 'package:cloud_firestore/cloud_firestore.dart';
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

  factory Task.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Task(
      id: doc.id,
      userId: data['userId'] as String,
      title: data['title'] as String,
      description: data['description'] as String?,
      dueDate: (data['dueDate'] as Timestamp).toDate(),
      rewardAmount: (data['rewardAmount'] as num?)?.toDouble() ?? 0.0,
      penaltyAmount: (data['penaltyAmount'] as num?)?.toDouble() ?? 0.0,
      status: TaskStatus.fromFirestoreValue(
        data['status'] as String? ?? 'pending',
      ),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] as Timestamp).toDate()
          : null,
      deadlineProcessed: data['deadlineProcessed'] as bool? ?? false,
      notificationScheduled: data['notificationScheduled'] as bool? ?? false,
      stripePaymentIntentId: data['stripePaymentIntentId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      if (description != null) 'description': description,
      'dueDate': Timestamp.fromDate(dueDate),
      'rewardAmount': rewardAmount,
      'penaltyAmount': penaltyAmount,
      'status': status.firestoreValue,
      'createdAt': Timestamp.fromDate(createdAt),
      if (completedAt != null) 'completedAt': Timestamp.fromDate(completedAt!),
      'deadlineProcessed': deadlineProcessed,
      'notificationScheduled': notificationScheduled,
      if (stripePaymentIntentId != null)
        'stripePaymentIntentId': stripePaymentIntentId,
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
