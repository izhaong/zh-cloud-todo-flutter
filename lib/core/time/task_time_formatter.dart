import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import 'task_time_mode.dart';

bool _timeZonesInitialized = false;

/// Formats an instant for task detail without changing the stored UTC value.
///
/// 两档固定在"存"与"看"两个方向上用的时区是**相反**的，判据是嘀嗒《01-任务/07-固定时间与固定时区.md》：
/// - `:48`「固定时区」＝"任务的时间会随着所在时区的不同而改变" ⇒ 墙上钟点记在锚点区，
///   人到了别的时区，**看到的是换算后的当地钟点**（`:50` 北京 11:00 → 莫斯科 06:00）；
/// - `:60`「固定时间」＝"不论所处时区如何变化，任务的时间都会保持一致" ⇒ **看到的是同一个墙上钟点**
///   （`:64` 7 点晨跑，在洛杉矶、巴塞罗那都在当地时间 7 点提醒）。
String formatTaskDateTime(
  DateTime instant, {
  required bool allDay,
  required TaskTimeMode mode,
  String? timeZone,
}) {
  final display = allDay
      ? instant
      : taskDisplayDateTime(
          instant,
          mode: mode,
          timeZone: timeZone,
        );
  final date =
      '${display.year.toString().padLeft(4, '0')}-'
      '${display.month.toString().padLeft(2, '0')}-'
      '${display.day.toString().padLeft(2, '0')}';
  if (allDay) return '$date (${_timeZoneLabel(mode, timeZone)})';
  return '$date ${display.hour.toString().padLeft(2, '0')}:'
      '${display.minute.toString().padLeft(2, '0')}'
      ' (${_timeZoneLabel(mode, timeZone)})';
}

/// Converts a stored instant to the wall clock used by task presentation.
DateTime taskDisplayDateTime(
  DateTime instant, {
  required TaskTimeMode mode,
  required String? timeZone,
}) {
  final location = _displayLocation(mode, timeZone);
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
  required TaskTimeMode mode,
  required String? timeZone,
}) {
  final display = allDay
      ? instant
      : taskDisplayDateTime(
          instant,
          mode: mode,
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
/// Invalid historical zones fall back to device-local so a cached bad value
/// never makes the task unusable; the server still rejects new invalid IANA
/// values on write.
DateTime taskDateTimeFromWallClock(
  DateTime wallClock, {
  required TaskTimeMode mode,
  required String? timeZone,
}) {
  final location = _storageLocation(mode, timeZone);
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
  required TaskTimeMode mode,
  required String? timeZone,
}) {
  final display = taskDisplayDateTime(
    instant,
    mode: mode,
    timeZone: timeZone,
  );
  return taskDateTimeFromWallClock(
    DateTime(
      day.year,
      day.month,
      day.day,
      display.hour,
      display.minute,
      display.second,
      display.millisecond,
      display.microsecond,
    ),
    mode: mode,
    timeZone: timeZone,
  );
}

/// 看：只有「固定时间」要把钟点钉在锚点区；「固定时区」与未选都跟设备时区走。
timezone.Location? _displayLocation(TaskTimeMode mode, String? timeZone) {
  if (mode != TaskTimeMode.fixedTime) return null;
  return _resolveLocation(timeZone);
}

/// 存：「固定时区」把用户填的钟点按锚点区解释；「固定时间」按设备时区解释，锚点区只服务"看"。
timezone.Location? _storageLocation(TaskTimeMode mode, String? timeZone) {
  if (mode != TaskTimeMode.fixedTimezone) return null;
  return _resolveLocation(timeZone);
}

timezone.Location? _resolveLocation(String? timeZone) {
  if (timeZone == null || timeZone.trim().isEmpty) {
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

String _timeZoneLabel(TaskTimeMode mode, String? timeZone) {
  final zone = timeZone?.trim() ?? '';
  if (mode.requiresAnchorZone && zone.isNotEmpty) {
    return '$zone ${mode.label}';
  }
  return '本地时区';
}
