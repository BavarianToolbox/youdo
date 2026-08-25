import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/auth_repository.dart';
import '../domain/task.dart';

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
    await _client.from('tasks').insert({
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
    await _client
        .from('tasks')
        .update({
          'title': task.title,
          'description': task.description,
          'due_date': task.dueDate.toUtc().toIso8601String(),
          'reward_amount': task.rewardAmount,
          'penalty_amount': task.penaltyAmount,
        })
        .eq('id', task.id);
  }

  Future<void> deleteTask(String taskId) async {
    await _client.from('tasks').delete().eq('id', taskId);
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
