enum TaskStatus {
  pending,
  completedOnTime,
  completedLate,
  missed;

  String get databaseValue {
    return switch (this) {
      TaskStatus.pending => 'pending',
      TaskStatus.completedOnTime => 'completed_on_time',
      TaskStatus.completedLate => 'completed_late',
      TaskStatus.missed => 'missed',
    };
  }

  static TaskStatus fromDatabaseValue(String value) {
    return switch (value) {
      'completed_on_time' => TaskStatus.completedOnTime,
      'completed_late' => TaskStatus.completedLate,
      'missed' => TaskStatus.missed,
      _ => TaskStatus.pending,
    };
  }

  bool get isCompleted =>
      this == TaskStatus.completedOnTime || this == TaskStatus.completedLate;

  bool get isPending => this == TaskStatus.pending;

  bool get isMissed => this == TaskStatus.missed;
}
