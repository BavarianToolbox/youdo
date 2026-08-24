import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/task.dart';
import '../domain/task_status.dart';
import '../../auth/data/auth_repository.dart';

class TasksRepository {
  TasksRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference get _tasksRef => _firestore.collection('tasks');

  Stream<List<Task>> watchTasks(String userId) {
    return _tasksRef
        .where('userId', isEqualTo: userId)
        .orderBy('dueDate')
        .snapshots()
        .map((snap) => snap.docs.map(Task.fromFirestore).toList());
  }

  Future<Task?> getTask(String taskId) async {
    final doc = await _tasksRef.doc(taskId).get();
    if (!doc.exists) return null;
    return Task.fromFirestore(doc);
  }

  Future<String> createTask(Task task) async {
    final docRef = _tasksRef.doc(task.id);
    await docRef.set(task.toFirestore());
    return task.id;
  }

  Future<void> updateTask(Task task) async {
    await _tasksRef.doc(task.id).update(task.toFirestore());
  }

  Future<void> deleteTask(String taskId) async {
    await _tasksRef.doc(taskId).delete();
  }

  Future<void> markComplete(String taskId, {required bool isOnTime}) async {
    final status = isOnTime
        ? TaskStatus.completedOnTime
        : TaskStatus.completedLate;
    await _tasksRef.doc(taskId).update({
      'status': status.firestoreValue,
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateNotificationScheduled(String taskId) async {
    await _tasksRef.doc(taskId).update({'notificationScheduled': true});
  }
}

final tasksRepositoryProvider = Provider<TasksRepository>((ref) {
  return TasksRepository(FirebaseFirestore.instance);
});

final taskListProvider = StreamProvider<List<Task>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value([]);
  return ref.watch(tasksRepositoryProvider).watchTasks(user.uid);
});

final taskProvider = FutureProvider.family<Task?, String>((ref, taskId) {
  return ref.watch(tasksRepositoryProvider).getTask(taskId);
});
