import 'package:flutter_test/flutter_test.dart';
import 'package:youdo/features/tasks/domain/task_status.dart';

void main() {
  group('TaskStatus', () {
    test('round-trips persisted values', () {
      for (final status in TaskStatus.values) {
        expect(TaskStatus.fromDatabaseValue(status.databaseValue), status);
      }
    });

    test('falls back to pending for unknown persisted values', () {
      expect(TaskStatus.fromDatabaseValue('unknown'), TaskStatus.pending);
    });

    test('exposes status categories', () {
      expect(TaskStatus.pending.isPending, isTrue);
      expect(TaskStatus.completedOnTime.isCompleted, isTrue);
      expect(TaskStatus.completedLate.isCompleted, isTrue);
      expect(TaskStatus.missed.isMissed, isTrue);
    });
  });
}
