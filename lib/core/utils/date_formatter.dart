import 'package:intl/intl.dart';

class DateFormatter {
  static final _dateFormat = DateFormat('MMM d, yyyy');
  static final _timeFormat = DateFormat('h:mm a');
  static final _dateTimeFormat = DateFormat('MMM d, yyyy • h:mm a');
  static final _shortDate = DateFormat('MMM d');

  static String formatDate(DateTime dt) => _dateFormat.format(dt);
  static String formatTime(DateTime dt) => _timeFormat.format(dt);
  static String formatDateTime(DateTime dt) => _dateTimeFormat.format(dt);
  static String formatShort(DateTime dt) => _shortDate.format(dt);

  static String formatRelative(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dt.year, dt.month, dt.day);
    final diff = target.difference(today).inDays;

    if (diff == 0) return 'Today, ${_timeFormat.format(dt)}';
    if (diff == 1) return 'Tomorrow, ${_timeFormat.format(dt)}';
    if (diff == -1) return 'Yesterday, ${_timeFormat.format(dt)}';
    if (diff < 0) return '${-diff}d overdue';
    if (diff < 7) return '${_shortDate.format(dt)}, ${_timeFormat.format(dt)}';
    return _dateTimeFormat.format(dt);
  }
}
