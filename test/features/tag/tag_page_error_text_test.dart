import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/tag/tag_page.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';

import '../../support/todo_visual_fixture.dart';

/// Issue #468：页面级错误分支不得把异常原文渲染出来。
///
/// 2026-10-03 web 端实测（`flutter build web --release` + test 后端重启中）在习惯页量到
/// 整段英文 `DioException [connection error]: ... developer.mozilla.org ...`，
/// 这里用标签页的同形分支把「中文原因 + 零原文」钉住。
void main() {
  Future<void> pumpFailingTagPage(WidgetTester tester) async {
    final fixture = await TodoVisualFixture.create(
      overridesBuilder: (database) => [
        tagsStreamProvider.overrideWith(
          (ref) => Stream<List<TodoTag>>.error(
            DioException(
              requestOptions: RequestOptions(path: '/app-api/todo/tag/list'),
              type: DioExceptionType.connectionError,
              error: StateError(
                'The XMLHttpRequest onError callback was called. See '
                'https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS#simple_requests',
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(fixture.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: fixture.container,
        child: MaterialApp(
          theme: ThemeData.light().copyWith(
            extensions: const [AppThemeExtension(AppColors.light)],
          ),
          home: const TagPage(),
        ),
      ),
    );
    // loading 态是无限旋转的 CircularProgressIndicator，pumpAndSettle 永不静止 ⇒ 只推进有限帧。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
  }

  testWidgets('标签页加载失败时给中文原因', (tester) async {
    await pumpFailingTagPage(tester);
    expect(
      find.text('加载标签失败: 网络连接不通，请检查网络后重试'),
      findsOneWidget,
      reason: 'describeError 的连接失败档要出现在页面上',
    );
  });

  testWidgets('标签页不渲染异常原文', (tester) async {
    await pumpFailingTagPage(tester);
    for (final needle in const [
      'DioException',
      'connection error',
      'XMLHttpRequest',
      'mozilla',
      'CORS',
      'Content-Type',
    ]) {
      expect(
        find.textContaining(needle),
        findsNothing,
        reason: '界面文案里不该出现异常原文片段「$needle」',
      );
    }
  });
}
