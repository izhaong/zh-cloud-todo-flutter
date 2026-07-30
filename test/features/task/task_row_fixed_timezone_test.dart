import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/features/task/widgets/task_row_host.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';

void main() {
  testWidgets('任务行按固定时区墙钟显示今天', (tester) async {
    final task = TodoTask(
      id: 'fixed-zone-row',
      listId: 'inbox',
      title: '洛杉矶任务行',
      completed: false,
      cancelled: false,
      priority: 0,
      isPinned: false,
      sortOrder: 0,
      dueAt: DateTime.utc(2026, 7, 12, 2),
      allDay: false,
      timeZone: 'America/Los_Angeles',
      fixedTimezone: true,
      updatedAt: DateTime.utc(2026, 7, 11),
      createdAt: DateTime.utc(2026, 7, 11),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentDateTimeProvider.overrideWithValue(
            () => DateTime(2026, 7, 11, 12),
          ),
          tagRepositoryProvider.overrideWithValue(null),
          taskRepositoryProvider.overrideWithValue(null),
        ],
        child: MaterialApp(
          home: Scaffold(body: TaskRowHost(task: task)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('今天'), findsOneWidget);
  });
}
