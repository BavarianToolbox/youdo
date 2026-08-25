import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/auth_repository.dart';
import '../domain/task.dart';

abstract interface class TasksGateway {
  Stream<List<Map<String, dynamic>>> watchTasks(String userId);
  Future<Map<String, dynamic>?> getTask(String taskId);
  Future<void> insertTask(Map<String, dynamic> fields);
  Future<void> updateTask(String taskId, Map<String, dynamic> fields);
  Future<void> deleteTask(String taskId);
}

class SupabaseTasksGateway implements TasksGateway {
  SupabaseTasksGateway(this._client);

  final SupabaseClient _client;

  @override
  Stream<List<Map<String, dynamic>>> watchTasks(String userId) => _client
      .from('tasks')
      .stream(primaryKey: ['id'])
      .eq('user_id', userId)
      .order('due_date');

  @override
  Future<Map<String, dynamic>?> getTask(String taskId) =>
      _client.from('tasks').select().eq('id', taskId).maybeSingle();

  @override
  Future<void> insertTask(Map<String, dynamic> fields) async {
    await _client.from('tasks').insert(fields);
  }

  @override
  Future<void> updateTask(String taskId, Map<String, dynamic> fields) async {
    await _client.from('tasks').update(fields).eq('id', taskId);
  }

  @override
  Future<void> deleteTask(String taskId) async {
    await _client.from('tasks').delete().eq('id', taskId);
  }
}

class TasksRepository {
  TasksRepository(SupabaseClient client)
    : this.gateway(SupabaseTasksGateway(client));

  TasksRepository.gateway(this._gateway);

  final TasksGateway _gateway;

  Stream<List<Task>> watchTasks(String userId) {
    return _gateway
        .watchTasks(userId)
        .map((rows) => rows.map(Task.fromJson).toList());
  }

  Future<Task?> getTask(String taskId) async {
    final data = await _gateway.getTask(taskId);
    return data == null ? null : Task.fromJson(data);
  }

  Future<String> createTask(Task task) async {
    await _gateway.insertTask({
      'id': task.id,
      'user_id': task.userId,
      'title': task.title,
      'description': task.description,
      'due_date': task.dueDate.toUtc().toIso8601String(),
      'reward_amount': task.rewardAmount,
      'penalty_amount': task.penaltyAmount,
    });
    return task.id;
  }

  Future<void> updateTask(Task task) async {
    await _gateway.updateTask(task.id, {
      'title': task.title,
      'description': task.description,
      'due_date': task.dueDate.toUtc().toIso8601String(),
      'reward_amount': task.rewardAmount,
      'penalty_amount': task.penaltyAmount,
    });
  }

  Future<void> deleteTask(String taskId) async {
    await _gateway.deleteTask(taskId);
  }

  Future<void> updateNotificationScheduled(String taskId) async {
    await _gateway.updateTask(taskId, {'notification_scheduled': true});
  }
}

final tasksRepositoryProvider = Provider<TasksRepository>((ref) {
  return TasksRepository(ref.watch(supabaseClientProvider));
});

final taskListProvider = StreamProvider<List<Task>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value([]);
  return ref.watch(tasksRepositoryProvider).watchTasks(user.id);
});

final taskProvider = FutureProvider.family<Task?, String>((ref, taskId) {
  return ref.watch(tasksRepositoryProvider).getTask(taskId);
});
