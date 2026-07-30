import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/notification/local_notification_service.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/home/home_shell.dart';
import 'package:zh_cloud_todo_flutter/features/reminder/reminder_inbox_page.dart';
import 'package:zh_cloud_todo_flutter/state/session_state.dart';

import '../../support/todo_visual_fixture.dart';

void main() {
  testWidgets('notification tap opens the matching local task detail', (
    tester,
  ) async {
    final fixture = await _pumpHome(tester);
    await (fixture.database.update(fixture.database.todoTasks)
          ..where((task) => task.id.equals(TodoVisualFixture.todayTaskId)))
        .write(const TodoTasksCompanion(serverId: Value(201)));

    fixture.container
        .read(localNotificationServiceProvider)
        .dispatchNotificationResponseForTesting(
          const NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotification,
            payload: 'reminder:301:1_7:1785312300000:201',
          ),
        );
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const Key('task-row-selected-${TodoVisualFixture.todayTaskId}'),
      ),
      findsOneWidget,
    );
    final detail = find.byKey(const Key('todo-detail'));
    expect(detail, findsOneWidget);
    expect(
      find.descendant(of: detail, matching: find.text('完成 Todo 工作区视觉评审')),
      findsOneWidget,
    );
  });

  testWidgets('notification tap from another account is ignored', (
    tester,
  ) async {
    final fixture = await _pumpHome(tester);
    await (fixture.database.update(fixture.database.todoTasks)
          ..where((task) => task.id.equals(TodoVisualFixture.todayTaskId)))
        .write(const TodoTasksCompanion(serverId: Value(201)));

    fixture.container
        .read(localNotificationServiceProvider)
        .dispatchNotificationResponseForTesting(
          const NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotification,
            payload: 'reminder:302:other_user:1785312300000:201',
          ),
        );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('todo-detail')), findsOneWidget);
    expect(
      find.byKey(
        const Key('task-row-selected-${TodoVisualFixture.todayTaskId}'),
      ),
      findsNothing,
    );
    expect(find.byType(ReminderInboxPage), findsNothing);
  });

  testWidgets('legacy notification payload falls back to reminder inbox', (
    tester,
  ) async {
    final fixture = await _pumpHome(tester);

    fixture.container
        .read(localNotificationServiceProvider)
        .dispatchNotificationResponseForTesting(
          const NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotification,
            payload: 'reminder:303:1_7:1785312300000',
          ),
        );
    await tester.pumpAndSettle();

    expect(find.byType(ReminderInboxPage), findsOneWidget);
  });

  testWidgets('notification lookup does not navigate after shell is disposed', (
    tester,
  ) async {
    final fixture = await _pumpHome(tester);
    await (fixture.database.update(fixture.database.todoTasks)
          ..where((task) => task.id.equals(TodoVisualFixture.todayTaskId)))
        .write(const TodoTasksCompanion(serverId: Value(201)));

    fixture.container
        .read(localNotificationServiceProvider)
        .dispatchNotificationResponseForTesting(
          const NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotification,
            payload: 'reminder:304:1_7:1785312300000:201',
          ),
        );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('todo-detail')), findsNothing);
  });
}

Future<TodoVisualFixture> _pumpHome(WidgetTester tester) async {
  final fixture = await TodoVisualFixture.create(
    overridesBuilder: (_) => [
      sessionProvider.overrideWith(_TestSessionController.new),
    ],
  );
  addTearDown(fixture.dispose);
  addTearDown(fixture.container.read(localNotificationServiceProvider).dispose);
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: fixture.container,
      child: MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          extensions: const [AppThemeExtension(AppColors.light)],
        ),
        home: const HomeShell(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return fixture;
}

class _TestSessionController extends SessionController {
  @override
  TodoAuthSession? build() => const TodoAuthSession(
    userId: 7,
    accessToken: 'test-access',
    refreshToken: 'test-refresh',
    tenantId: '1',
    mobile: '13800000000',
  );
}
