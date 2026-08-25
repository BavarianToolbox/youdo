import 'package:flutter_test/flutter_test.dart';
import 'package:youdo/features/tasks/data/tasks_repository.dart';
import 'package:youdo/features/tasks/domain/task.dart';
import 'package:youdo/features/tasks/domain/task_status.dart';

void main() {
  late FakeTasksGateway gateway;
  late TasksRepository repository;

  setUp(() {
    gateway = FakeTasksGateway();
    repository = TasksRepository.gateway(gateway);
  });

  test('task stream maps database rows', () async {
    gateway.rows = Stream.value([_taskRow()]);

    final tasks = await repository.watchTasks('user-1').first;

    expect(gateway.watchedUserId, 'user-1');
    expect(tasks.single.title, 'Ship tests');
    expect(tasks.single.status, TaskStatus.pending);
  });

  test('getTask preserves a missing row', () async {
    expect(await repository.getTask('missing'), isNull);
  });

  test('create sends only client-editable task fields', () async {
    final task = _task();

    expect(await repository.createTask(task), task.id);
    expect(gateway.inserted, {
      'id': 'task-1',
      'user_id': 'user-1',
      'title': 'Ship tests',
      'description': 'Cover repository boundaries',
      'due_date': '2026-08-26T12:00:00.000Z',
      'reward_amount': 10.0,
      'penalty_amount': 5.0,
    });
    expect(gateway.inserted, isNot(contains('status')));
    expect(gateway.inserted, isNot(contains('completed_at')));
  });

  test('update cannot overwrite server-managed completion fields', () async {
    await repository.updateTask(
      _task().copyWith(
        status: TaskStatus.completedOnTime,
        completedAt: DateTime.utc(2026, 8, 25),
      ),
    );

    expect(gateway.updatedTaskId, 'task-1');
    expect(gateway.updated, isNot(contains('status')));
    expect(gateway.updated, isNot(contains('completed_at')));
    expect(gateway.updated, isNot(contains('user_id')));
  });

  test('delete and notification update target the requested task', () async {
    await repository.deleteTask('task-1');
    expect(gateway.deletedTaskId, 'task-1');

    await repository.updateNotificationScheduled('task-2');
    expect(gateway.updatedTaskId, 'task-2');
    expect(gateway.updated, {'notification_scheduled': true});
  });
}

Task _task() => Task(
  id: 'task-1',
  userId: 'user-1',
  title: 'Ship tests',
  description: 'Cover repository boundaries',
  dueDate: DateTime.utc(2026, 8, 26, 12),
  rewardAmount: 10,
  penaltyAmount: 5,
  createdAt: DateTime.utc(2026, 8, 25),
);

Map<String, dynamic> _taskRow() => {
  'id': 'task-1',
  'user_id': 'user-1',
  'title': 'Ship tests',
  'description': 'Cover repository boundaries',
  'due_date': '2026-08-26T12:00:00Z',
  'created_at': '2026-08-25T12:00:00Z',
  'status': 'pending',
};

class FakeTasksGateway implements TasksGateway {
  Stream<List<Map<String, dynamic>>> rows = const Stream.empty();
  Map<String, dynamic>? fetched;
  String? watchedUserId;
  Map<String, dynamic>? inserted;
  String? updatedTaskId;
  Map<String, dynamic>? updated;
  String? deletedTaskId;

  @override
  Stream<List<Map<String, dynamic>>> watchTasks(String userId) {
    watchedUserId = userId;
    return rows;
  }

  @override
  Future<Map<String, dynamic>?> getTask(String taskId) async => fetched;

  @override
  Future<void> insertTask(Map<String, dynamic> fields) async {
    inserted = fields;
  }

  @override
  Future<void> updateTask(String taskId, Map<String, dynamic> fields) async {
    updatedTaskId = taskId;
    updated = fields;
  }

  @override
  Future<void> deleteTask(String taskId) async {
    deletedTaskId = taskId;
  }
}
