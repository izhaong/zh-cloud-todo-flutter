import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/sync/sync_entities.dart';
import 'package:zh_cloud_todo_flutter/features/home/home_shell.dart';
import 'package:zh_cloud_todo_flutter/native/native_intents.dart';

import 'support/todo_visual_fixture.dart';
import 'support/todo_visual_test_harness.dart';

void main() {
  test('task add link requires an exact route, title, and valid due date', () {
    final request = NativeTaskAddRequest.tryParse(
      Uri.parse(
        'zhcloudtodo://task/add'
        '?title=%E6%8F%90%E4%BA%A4%E5%91%A8%E6%8A%A5&due=2026-08-01',
      ),
    );

    expect(request?.title, '提交周报');
    expect(request?.dueAt, DateTime(2026, 8, 1));
    expect(request?.allDay, isTrue);
    expect(
      NativeTaskAddRequest.tryParse(
        Uri.parse('zhcloudtodo://task/add?title=%20%20'),
      ),
      isNull,
    );
    expect(
      NativeTaskAddRequest.tryParse(
        Uri.parse('zhcloudtodo://task/delete?title=不能创建'),
      ),
      isNull,
    );
    expect(
      NativeTaskAddRequest.tryParse(
        Uri.parse('zhcloudtodo://task/add?title=坏日期&due=2026-02-30'),
      ),
      isNull,
    );
    expect(
      NativeTaskAddRequest.tryParse(
        Uri.parse('zhcloudtodo://task/add?title=a&title=b'),
      ),
      isNull,
    );
  });

  test('平台未注册热启动事件通道时主壳安全降级', () async {
    expect(await NativeIntents.incomingUris().toList(), isEmpty);
  });

  testWidgets('冷启动 task add 链接通过 Repository 和 outbox 创建任务', (tester) async {
    final fixture = await pumpTodoVisualScenario(
      tester,
      viewport: TodoVisualViewports.wide,
      fixtureSet: TodoVisualFixtureSet.empty,
      child: HomeShell(
        incomingUriStream: const Stream.empty(),
        initialUriLoader: () async => Uri.parse(
          'zhcloudtodo://task/add'
          '?title=%E5%86%B7%E5%90%AF%E5%8A%A8%E4%BB%BB%E5%8A%A1'
          '&due=2026-08-01',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tasks = await fixture.database
        .select(fixture.database.todoTasks)
        .get();
    final created = tasks.singleWhere((task) => task.title == '冷启动任务');
    expect(created.listId, TodoVisualFixture.inboxListId);
    expect(created.dueAt, DateTime(2026, 8, 1));
    expect(created.allDay, isTrue);

    final outbox = await fixture.database
        .select(fixture.database.todoSyncChanges)
        .get();
    expect(
      outbox.any(
        (change) =>
            change.entity == SyncEntities.task &&
            change.entityLocalId == created.id,
      ),
      isTrue,
    );
    expect(find.text('已通过快捷指令创建任务'), findsOneWidget);
  });

  testWidgets('连续热启动 task add 链接在主壳串行创建任务', (tester) async {
    final incomingUris = StreamController<Uri>();
    addTearDown(incomingUris.close);
    final fixture = await pumpTodoVisualScenario(
      tester,
      viewport: TodoVisualViewports.wide,
      fixtureSet: TodoVisualFixtureSet.empty,
      child: HomeShell(
        incomingUriStream: incomingUris.stream,
        initialUriLoader: () async => null,
      ),
    );

    incomingUris.add(
      Uri.parse(
        'zhcloudtodo://task/add?title=%E7%83%AD%E5%90%AF%E5%8A%A8%E4%BB%BB%E5%8A%A1A',
      ),
    );
    incomingUris.add(
      Uri.parse(
        'zhcloudtodo://task/add?title=%E7%83%AD%E5%90%AF%E5%8A%A8%E4%BB%BB%E5%8A%A1B',
      ),
    );
    await tester.pumpAndSettle();

    final tasks = await fixture.database
        .select(fixture.database.todoTasks)
        .get();
    expect(
      tasks
          .where((task) => task.title.startsWith('热启动任务'))
          .map((task) => task.title),
      containsAll(['热启动任务A', '热启动任务B']),
    );
    expect(find.text('已通过快捷指令创建任务'), findsOneWidget);
  });

  testWidgets('无效 task add 链接不创建任务并显示恢复反馈', (tester) async {
    final fixture = await pumpTodoVisualScenario(
      tester,
      viewport: TodoVisualViewports.wide,
      fixtureSet: TodoVisualFixtureSet.empty,
      child: HomeShell(
        incomingUriStream: const Stream.empty(),
        initialUriLoader: () async =>
            Uri.parse('zhcloudtodo://task/add?title=%20&due=2026-02-30'),
      ),
    );
    await tester.pumpAndSettle();

    final tasks = await fixture.database
        .select(fixture.database.todoTasks)
        .get();
    expect(tasks, isEmpty);
    expect(find.text('快捷指令参数无效'), findsOneWidget);
  });
}
