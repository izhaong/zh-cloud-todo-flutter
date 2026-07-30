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
  final display = allDay
      ? instant
      : taskDisplayDateTime(
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

/// Converts a stored instant to the wall clock used by task presentation.
DateTime taskDisplayDateTime(
  DateTime instant, {
  required bool fixedTimezone,
  required String? timeZone,
}) {
  final location = _fixedLocation(fixedTimezone, timeZone);
  if (location == null) return instant.toLocal();
  return timezone.TZDateTime.from(instant.toUtc(), location);
}

/// Returns a timezone-neutral wall-clock value for task UI comparison.
///
/// [DateTime.compareTo] compares instants even for [timezone.TZDateTime], so
/// callers that group or sort by what the user sees must compare the copied
/// calendar fields instead. All-day values intentionally keep their stored
/// pure-date semantics and never shift through a timezone.
DateTime taskWallClockDateTime(
  DateTime instant, {
  required bool allDay,
  required bool fixedTimezone,
  required String? timeZone,
}) {
  final display = allDay
      ? instant
      : taskDisplayDateTime(
          instant,
          fixedTimezone: fixedTimezone,
          timeZone: timeZone,
        );
  return DateTime(
    display.year,
    display.month,
    display.day,
    display.hour,
    display.minute,
    display.second,
    display.millisecond,
    display.microsecond,
  );
}

/// Converts a user-selected wall clock back to the stored task instant.
///
/// Fixed IANA zones return UTC so DST offsets are resolved by the timezone
/// database. Floating or invalid historical zones remain device-local.
DateTime taskDateTimeFromWallClock(
  DateTime wallClock, {
  required bool fixedTimezone,
  required String? timeZone,
}) {
  final location = _fixedLocation(fixedTimezone, timeZone);
  if (location != null) {
    return timezone.TZDateTime(
      location,
      wallClock.year,
      wallClock.month,
      wallClock.day,
      wallClock.hour,
      wallClock.minute,
      wallClock.second,
      wallClock.millisecond,
      wallClock.microsecond,
    ).toUtc();
  }
  return DateTime(
    wallClock.year,
    wallClock.month,
    wallClock.day,
    wallClock.hour,
    wallClock.minute,
    wallClock.second,
    wallClock.millisecond,
    wallClock.microsecond,
  );
}

/// Moves an instant to [day] while preserving its presented wall-clock time.
DateTime taskDateTimeForDisplayDay(
  DateTime instant,
  DateTime day, {
  required bool fixedTimezone,
  required String? timeZone,
}) {
  final display = taskDisplayDateTime(
    instant,
    fixedTimezone: fixedTimezone,
    timeZone: timeZone,
  );
  final location = _fixedLocation(fixedTimezone, timeZone);
  if (location != null) {
    return timezone.TZDateTime(
      location,
      day.year,
      day.month,
      day.day,
      display.hour,
      display.minute,
      display.second,
      display.millisecond,
      display.microsecond,
    ).toUtc();
  }
  return DateTime(
    day.year,
    day.month,
    day.day,
    display.hour,
    display.minute,
    display.second,
    display.millisecond,
    display.microsecond,
  );
}

timezone.Location? _fixedLocation(bool fixedTimezone, String? timeZone) {
  if (!fixedTimezone || timeZone == null || timeZone.trim().isEmpty) {
    return null;
  }
  try {
    if (!_timeZonesInitialized) {
      timezone_data.initializeTimeZones();
      _timeZonesInitialized = true;
    }
    return timezone.getLocation(timeZone.trim());
  } catch (_) {
    // Old locally cached data may contain an invalid zone. The server rejects
    // new invalid IANA values, but this fallback keeps the task usable.
    return null;
  }
}

String _timeZoneLabel(bool fixedTimezone, String? timeZone) {
  if (fixedTimezone && timeZone != null && timeZone.trim().isNotEmpty) {
    return '${timeZone.trim()} 固定时区';
  }
  return '本地时区';
}
