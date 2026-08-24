import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/auth_repository.dart';
import '../domain/task.dart';
import '../domain/task_status.dart';

class TasksRepository {
  TasksRepository(this._client);

  final SupabaseClient _client;

  Stream<List<Task>> watchTasks(String userId) {
    return _client
        .from('tasks')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('due_date')
        .map((rows) => rows.map(Task.fromJson).toList());
  }

  Future<Task?> getTask(String taskId) async {
    final data = await _client
        .from('tasks')
        .select()
        .eq('id', taskId)
        .maybeSingle();
    return data == null ? null : Task.fromJson(data);
  }

  Future<String> createTask(Task task) async {
    await _client.from('tasks').insert(task.toJson());
    return task.id;
  }

  Future<void> updateTask(Task task) async {
    await _client.from('tasks').update(task.toJson()).eq('id', task.id);
  }

  Future<void> deleteTask(String taskId) async {
    await _client.from('tasks').delete().eq('id', taskId);
  }

  Future<void> markComplete(String taskId, {required bool isOnTime}) async {
    final status = isOnTime
        ? TaskStatus.completedOnTime
        : TaskStatus.completedLate;
    await _client
        .from('tasks')
        .update({
          'status': status.databaseValue,
          'completed_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', taskId);
  }

  Future<void> updateNotificationScheduled(String taskId) async {
    await _client
        .from('tasks')
        .update({'notification_scheduled': true})
        .eq('id', taskId);
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
