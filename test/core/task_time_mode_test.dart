import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import 'package:zh_cloud_todo_flutter/core/time/task_time_formatter.dart';
import 'package:zh_cloud_todo_flutter/core/time/task_time_mode.dart';

/// 判据源：嘀嗒《01-任务/07-固定时间与固定时区.md》
/// `:48`「选择「固定时区」，即意味着任务的时间会随着所在时区的不同而改变」
/// （`:50` 示例：北京上午 11 点的任务，在莫斯科显示为上午 6 点）
/// `:60`「选择「固定时间」，即意味着不论所处时区如何变化，任务的时间都会保持一致」
/// （`:64` 示例：设 7 点晨跑，在洛杉矶、巴塞罗那都在当地时间 7 点提醒）
void main() {
  setUpAll(() => tz_data.initializeTimeZones());

  // 绝对时刻：UTC 03:00 = 北京 11:00 = 莫斯科 06:00 = 洛杉矶（-07:00）20:00 前一天
  final instant = DateTime.utc(2026, 5, 1, 3, 0);

  group('档位用词照抄嘀嗒', () {
    test('只有两档有界面用词，未选那档不发明名字', () {
      expect(TaskTimeMode.fixedTimezone.label, '固定时区');
      expect(TaskTimeMode.fixedTime.label, '固定时间');
      expect(TaskTimeMode.floating.label, isNull);
    });

    test('wire 值与服务端 time_mode 同口径', () {
      expect(TaskTimeMode.floating.wire, 0);
      expect(TaskTimeMode.fixedTimezone.wire, 1);
      expect(TaskTimeMode.fixedTime.wire, 2);
      expect(TaskTimeMode.fromWire(2), TaskTimeMode.fixedTime);
      expect(
        TaskTimeMode.fromWire(TaskTimeMode.fixedTimezone.wire),
        TaskTimeMode.fixedTimezone,
      );
      expect(TaskTimeMode.fromWire(null), TaskTimeMode.floating);
      expect(TaskTimeMode.fromWire(99), TaskTimeMode.floating);
    });

    test('旧位＝"勾过某一档固定"，两档都为 true；存量 true 读成「固定时间」', () {
      expect(TaskTimeMode.legacyFlagOf(TaskTimeMode.fixedTimezone), isTrue);
      expect(TaskTimeMode.legacyFlagOf(TaskTimeMode.fixedTime), isTrue);
      expect(TaskTimeMode.legacyFlagOf(TaskTimeMode.floating), isFalse);
      expect(TaskTimeMode.fromLegacyFlag(true), TaskTimeMode.fixedTime);
      expect(TaskTimeMode.fromLegacyFlag(false), TaskTimeMode.floating);
    });

    test('两档固定都要锚点时区，未选不要', () {
      expect(TaskTimeMode.fixedTimezone.requiresAnchorZone, isTrue);
      expect(TaskTimeMode.fixedTime.requiresAnchorZone, isTrue);
      expect(TaskTimeMode.floating.requiresAnchorZone, isFalse);
    });
  });

  group('展示语义', () {
    test('「固定时区」按设备时区走，墙钟会变（嘀嗒 :48/:50）', () {
      final display = taskDisplayDateTime(
        instant,
        mode: TaskTimeMode.fixedTimezone,
        timeZone: 'Asia/Shanghai',
      );
      final local = instant.toLocal();
      expect(display.hour, local.hour);
      expect(display.minute, local.minute);
    });

    test('「固定时间」钉住墙钟，不随设备时区变（嘀嗒 :60/:64）', () {
      final display = taskDisplayDateTime(
        instant,
        mode: TaskTimeMode.fixedTime,
        timeZone: 'America/Los_Angeles',
      );
      expect(display.hour, 20);
      expect(display.day, 30);
      expect(display.month, 4);
    });

    test('「固定时间」缺锚点时退回设备时区，不抛错', () {
      final display = taskDisplayDateTime(
        instant,
        mode: TaskTimeMode.fixedTime,
        timeZone: null,
      );
      expect(display.hour, instant.toLocal().hour);
    });

    test('未选（浮动）与今天一致：跟设备时区', () {
      final floating = taskDisplayDateTime(
        instant,
        mode: TaskTimeMode.floating,
        timeZone: 'Asia/Shanghai',
      );
      expect(floating.hour, instant.toLocal().hour);
    });

    test('全天任务不穿时区，标签按档位用词', () {
      final fixedTime = formatTaskDateTime(
        instant,
        allDay: true,
        mode: TaskTimeMode.fixedTime,
        timeZone: 'America/Los_Angeles',
      );
      expect(fixedTime, contains('固定时间'));
      expect(fixedTime, startsWith('2026-05-01'));

      final labeled = formatTaskDateTime(
        instant,
        allDay: false,
        mode: TaskTimeMode.fixedTimezone,
        timeZone: 'Asia/Shanghai',
      );
      expect(labeled, contains('固定时区'));
    });

    test('按墙钟分组用的取值跟随档位语义', () {
      final wall = taskWallClockDateTime(
        instant,
        allDay: false,
        mode: TaskTimeMode.fixedTime,
        timeZone: 'Europe/Moscow',
      );
      expect(wall.hour, 6);
      expect(wall.day, 1);
    });
  });
}
