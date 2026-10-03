import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_entities.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/repeat_rule_repository.dart';

/// specs/083 / FL Issue #324：重复任务缺「法定工作日」与「法定节假日」两档。
///
/// 嘀嗒《02-功能指南/01-任务/10-设置重复任务》`:65`「- 法定工作日」
/// `:67`「任务将避开周末和法定节假日，在法定工作日重复」；
/// `:78`「- 法定节假日」`:80`「任务将遵循国家放假安排，在法定节假日重复」。
///
/// 服务端契约已合并（zh-cloud-service `641aa0768ba2`，Issue #319）：两档的命中判定由
/// `todo_calendar_holiday` 字典表驱动 ⇒ 客户端**不得**自己派生星期集（Issue #324
/// 「别做的事：不要用「周一到周五」近似「法定工作日」」）。
void main() {
  Future<(AppDatabase, RepeatRuleRepository)> openRepo() async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    return (db, RepeatRuleRepository(db, SyncChangeQueue(db)));
  }

  Future<TodoRepeatRule> saveRule(
    RepeatRuleRepository repo,
    String frequency, {
    Iterable<int>? weekdays,
  }) {
    return repo.save(
      taskId: 'task-legal-1',
      frequency: frequency,
      weekdays: weekdays,
      startAt: DateTime.parse('2026-02-13T09:00:00'),
    );
  }

  Future<Map<String, dynamic>> lastPayload(AppDatabase db) async {
    final rows = await (db.select(
      db.todoSyncChanges,
    )..where((t) => t.entity.equals(SyncEntities.repeatRule))).get();
    return jsonDecode(rows.last.payloadJson) as Map<String, dynamic>;
  }

  test('两档都被接受，落库 freq 是大写常量', () async {
    final (_, repo) = await openRepo();

    final workday = await saveRule(repo, 'LEGAL_WORKDAY');
    final holiday = await saveRule(repo, 'LEGAL_HOLIDAY');

    expect(workday.freq, 'LEGAL_WORKDAY');
    expect(holiday.freq, 'LEGAL_HOLIDAY');
  });

  test('两档不派生星期集：byDay 必须为空（这是本轮的支点）', () async {
    final (_, repo) = await openRepo();

    final workday = await saveRule(repo, 'LEGAL_WORKDAY');
    final holiday = await saveRule(repo, 'LEGAL_HOLIDAY');

    expect(
      workday.byDay,
      isNull,
      reason:
          '派生成 1,2,3,4,5 就等于把「法定工作日」偷偷改回「周一至周五」，'
          '调休放假日会被算成上班日，且这条假事还会同步到服务端',
    );
    expect(holiday.byDay, isNull, reason: '「法定节假日」的命中集由字典表决定，写死任何星期集都是假事实');
  });

  test('既有 WEEKDAY/WEEKEND 仍各自派生星期集（本轮没把它们带倒）', () async {
    final (_, repo) = await openRepo();

    final weekday = await saveRule(repo, 'WEEKDAY');
    final weekend = await saveRule(repo, 'WEEKEND');

    expect(weekday.byDay, '1,2,3,4,5');
    expect(weekend.byDay, '6,7');
  });

  test('出库 payload 用小写连字符，与服务端枚举 wire 值一致', () async {
    final (db, repo) = await openRepo();

    await saveRule(repo, 'LEGAL_WORKDAY');
    expect(
      (await lastPayload(db))['frequency'],
      'legal-workday',
      reason:
          '服务端 TodoRepeatFrequencyEnum 的取值就是 legal-workday，'
          '大小写或下划线不对会被 validateRepeatRulePayload 直接拒收',
    );

    await saveRule(repo, 'LEGAL_HOLIDAY');
    expect((await lastPayload(db))['frequency'], 'legal-holiday');
  });

  test('未知档位仍然被拒（放宽只针对这两档，不是开了个口子）', () async {
    final (_, repo) = await openRepo();

    expect(
      () => saveRule(repo, 'LEGAL'),
      throwsA(isA<ArgumentError>()),
      reason: '前缀匹配会把 LEGAL 当成合法值放过 ⇒ 到服务端才炸，本地要先拦住',
    );
    expect(() => saveRule(repo, 'HOLIDAY'), throwsA(isA<ArgumentError>()));
  });

  test('两档都收「每隔 N 次」且 N 数的是命中的天（与服务端口径同族）', () async {
    final (_, repo) = await openRepo();

    final rule = await repo.save(
      taskId: 'task-legal-2',
      frequency: 'LEGAL_HOLIDAY',
      intervalValue: 2,
      startAt: DateTime.parse('2026-05-01T09:00:00'),
    );

    expect(rule.interval, 2);
    expect(rule.freq, 'LEGAL_HOLIDAY');
  });
}
