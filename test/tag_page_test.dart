import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/features/tag/tag_page.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';

void main() {
  testWidgets('renders a child tag with its parent path', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime.utc(2026, 7, 19);
    await db
        .into(db.todoTags)
        .insert(
          TodoTagsCompanion.insert(
            id: 'project',
            name: '项目',
            updatedAt: now,
            createdAt: now,
          ),
        );
    await db
        .into(db.todoTags)
        .insert(
          TodoTagsCompanion.insert(
            id: 'client',
            parentId: const Value('project'),
            name: '客户端',
            updatedAt: now,
            createdAt: now,
          ),
        );
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TagPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('项目 / 客户端'), findsOneWidget);
  });

  testWidgets('creates a child tag through the parent picker', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime.utc(2026, 7, 19);
    await db
        .into(db.todoTags)
        .insert(
          TodoTagsCompanion.insert(
            id: 'project',
            name: '项目',
            updatedAt: now,
            createdAt: now,
          ),
        );
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TagPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '客户端');
    await tester.tap(find.byKey(const Key('tag-parent-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('项目').last);
    await tester.pumpAndSettle();
    final saveButton = find.widgetWithText(FilledButton, '保存');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    final child = await (db.select(
      db.todoTags,
    )..where((tag) => tag.name.equals('客户端'))).getSingle();
    expect(child.parentId, 'project');
    final outbox = await (db.select(
      db.todoSyncChanges,
    )..where((entry) => entry.entityLocalId.equals(child.id))).getSingle();
    expect(outbox.payloadJson, contains('project'));
  });

  testWidgets('explains that deleting a parent reparents its children', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime.utc(2026, 7, 19);
    await db
        .into(db.todoTags)
        .insert(
          TodoTagsCompanion.insert(
            id: 'project',
            name: '项目',
            updatedAt: now,
            createdAt: now,
          ),
        );
    await db
        .into(db.todoTags)
        .insert(
          TodoTagsCompanion.insert(
            id: 'client',
            parentId: const Value('project'),
            name: '客户端',
            updatedAt: now,
            createdAt: now,
          ),
        );
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TagPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();

    expect(find.textContaining('关联任务将解除；直接子标签会移至顶层。'), findsOneWidget);
  });
}
