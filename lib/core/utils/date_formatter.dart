import 'package:intl/intl.dart';

/// Reusable utility for formatting timestamps and durations across Ops views.
class DateFormatter {
  DateFormatter._();

  static final DateFormat _dateTimeFormat = DateFormat('dd MMM yyyy, HH:mm:ss');
  static final DateFormat _shortDateFormat = DateFormat('dd MMM, HH:mm');
  static final DateFormat _timeOnlyFormat = DateFormat('HH:mm:ss');

  /// Formats ISO string or DateTime to `dd MMM yyyy, HH:mm:ss`
  static String formatFull(dynamic date) {
    final dt = _parse(date);
    if (dt == null) return '—';
    return _dateTimeFormat.format(dt.toLocal());
  }

  /// Formats ISO string or DateTime to `dd MMM, HH:mm`
  static String formatShort(dynamic date) {
    final dt = _parse(date);
    if (dt == null) return '—';
    return _shortDateFormat.format(dt.toLocal());
  }

  /// Formats time only: `HH:mm:ss`
  static String formatTime(dynamic date) {
    final dt = _parse(date);
    if (dt == null) return '—';
    return _timeOnlyFormat.format(dt.toLocal());
  }

  /// Formats date to relative string e.g. "Just now", "5m ago", "2h ago"
  static String formatRelative(dynamic date) {
    final dt = _parse(date);
    if (dt == null) return '—';
    final now = DateTime.now();
    final diff = now.difference(dt.toLocal());

    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return formatShort(dt);
    }
  }

  /// Formats elapsed duration (e.g. for maintenance downtime) into `Xm Ys`
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  static DateTime? _parse(dynamic input) {
    if (input == null) return null;
    if (input is DateTime) return input;
    if (input is String) return DateTime.tryParse(input);
    if (input is int) return DateTime.fromMillisecondsSinceEpoch(input);
    return null;
  }
}
