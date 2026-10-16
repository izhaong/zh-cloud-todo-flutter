import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/filter/saved_filters_page.dart';
import 'package:zh_cloud_todo_flutter/features/tag/tag_page.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/filter_repository.dart';

import '../support/todo_visual_fixture.dart';

/// FL #375：**失败保留已加载数据**。
///
/// 这些页面的数据来自 `StreamProvider`。以前是裸 `.when(...)`，而 `AsyncError`
/// 在「已经有值」时**仍然**走 `error:` 分支 ⇒ 流抖一下，整页已列出的内容就被换成
/// 「加载失败」，用户看到列表直接消失。
///
/// 修法（与已合并的批次 1 同一条口径）：
/// 1. `skipError: true` —— Riverpod 2.6.1 `common.dart:738` 的判据是
///    `if (hasError && (!hasValue || !skipError))`：**有值**时跳过 error 分支；
///    首值就没读到（`!hasValue`）时仍走失败态。
/// 2. 有值且失败时另给一条**可见**提示（`AppRefreshFailedHint`）。
///
/// 反向探针：把 `skipError: true` 去掉 ⇒ 数据断言转红（值被 error 分支换掉）。
void main() {
  ThemeData themed() => ThemeData.light().copyWith(
    extensions: const [AppThemeExtension(AppColors.light)],
  );

  Future<void> pumpWith(
    WidgetTester tester,
    TodoVisualFixture fixture,
    Widget home,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: fixture.container,
        child: MaterialApp(theme: themed(), home: home),
      ),
    );
    // 不能 pumpAndSettle：加载态是 CircularProgressIndicator（无限动画），
    // 在流还没发值时会一直等下去 ⇒ 超时。
    await tester.pump();
  }

  /// 把流推到「有数据」，再推到「失败」，断言数据还在且提示可见。
  Future<void> expectKeepsLoadedData(
    WidgetTester tester, {
    required StreamController<Object> controller,
    required Object payload,
    required Finder dataFinder,
    required String what,
  }) async {
    controller.add(payload);
    await tester.pump();
    await tester.pump();
    expect(dataFinder, findsOneWidget, reason: '先证明数据真的渲染出来了');

    controller.addError(StateError('boom'));
    await tester.pump();
    await tester.pump();

    expect(dataFinder, findsOneWidget, reason: '$what：失败时已加载内容不许被换成失败态');
    expect(
      find.byKey(const Key('app-refresh-failed-hint')),
      findsOneWidget,
      reason: '保留旧数据的同时必须给一条可见的失败提示，否则用户不知道刷新失败了',
    );
  }

  testWidgets('SavedFiltersPage：流报错后仍列出已加载的过滤器并给出提示', (tester) async {
    final filters = StreamController<List<TodoFilter>>();
    addTearDown(filters.close);

    final fixture = await TodoVisualFixture.create(
      overridesBuilder: (database) => [
        savedFiltersStreamProvider.overrideWith((ref) => filters.stream),
        foldersStreamProvider.overrideWith(
          (ref) => const Stream<List<TodoFolder>>.empty(),
        ),
      ],
    );
    addTearDown(fixture.dispose);

    final saved = await FilterRepository(
      fixture.database,
      SyncChangeQueue(fixture.database),
    ).save(name: '高优先级英语', conditions: const TodoFilterConditions());

    await pumpWith(tester, fixture, const SavedFiltersPage());

    await expectKeepsLoadedData(
      tester,
      controller: filters,
      payload: [saved],
      dataFinder: find.text('高优先级英语'),
      what: '过滤器列表',
    );
  });

  testWidgets('TagPage：流报错后仍列出已加载的标签并给出提示', (tester) async {
    final controller = StreamController<List<TodoTag>>();
    addTearDown(controller.close);

    final fixture = await TodoVisualFixture.create(
      overridesBuilder: (database) => [
        tagsStreamProvider.overrideWith((ref) => controller.stream),
      ],
    );
    addTearDown(fixture.dispose);

    final tags = await (fixture.database.select(
      fixture.database.todoTags,
    )).get();
    expect(tags, isNotEmpty, reason: 'fixture 应先有标签，否则下面的断言是空的');

    await pumpWith(tester, fixture, const TagPage());

    await expectKeepsLoadedData(
      tester,
      controller: controller,
      payload: tags,
      dataFinder: find.text('专注').first,
      what: '标签列表',
    );
  });
}
