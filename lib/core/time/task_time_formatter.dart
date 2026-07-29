import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

bool _timeZonesInitialized = false;

/// Formats an instant for task detail without changing the stored UTC value.
///
/// Fixed-timezone tasks keep their configured IANA zone's wall clock, while
/// floating tasks follow the current device timezone.
String formatTaskDateTime(
  DateTime instant, {
  required bool allDay,
  required bool fixedTimezone,
  String? timeZone,
}) {
  final display = _displayTime(
    instant,
    fixedTimezone: fixedTimezone,
    timeZone: timeZone,
  );
  final date =
      '${display.year.toString().padLeft(4, '0')}-'
      '${display.month.toString().padLeft(2, '0')}-'
      '${display.day.toString().padLeft(2, '0')}';
  if (allDay) return '$date (${_timeZoneLabel(fixedTimezone, timeZone)})';
  return '$date ${display.hour.toString().padLeft(2, '0')}:'
      '${display.minute.toString().padLeft(2, '0')}'
      ' (${_timeZoneLabel(fixedTimezone, timeZone)})';
}

DateTime _displayTime(
  DateTime instant, {
  required bool fixedTimezone,
  required String? timeZone,
}) {
  if (!fixedTimezone || timeZone == null || timeZone.trim().isEmpty) {
    return instant.toLocal();
  }
  try {
    if (!_timeZonesInitialized) {
      timezone_data.initializeTimeZones();
      _timeZonesInitialized = true;
    }
    return timezone.TZDateTime.from(
      instant.toUtc(),
      timezone.getLocation(timeZone),
    );
  } catch (_) {
    // Old locally cached data may contain an invalid zone. The server rejects
    // new invalid IANA values, but this fallback keeps the detail readable.
    return instant.toLocal();
  }
}

String _timeZoneLabel(bool fixedTimezone, String? timeZone) {
  if (fixedTimezone && timeZone != null && timeZone.trim().isNotEmpty) {
    return '${timeZone.trim()} 固定时区';
  }
  return '本地时区';
}
