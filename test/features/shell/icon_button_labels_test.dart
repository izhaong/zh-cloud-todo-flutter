import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/countdown/countdown_page.dart';
import 'package:zh_cloud_todo_flutter/features/folder/folder_page.dart';
import 'package:zh_cloud_todo_flutter/features/habit/habit_page.dart';
import 'package:zh_cloud_todo_flutter/features/list/list_page.dart';
import 'package:zh_cloud_todo_flutter/features/tag/tag_page.dart';

import '../../support/todo_visual_fixture.dart';

/// 图标按钮的可访问名称。
///
/// 这些按钮只有图标没有文字，读屏下若没有 tooltip/语义名就只剩「按钮」两个字，
/// 用户无法知道按下去会发生什么。第 218 轮 web 实测在标签页量到
/// 「新建标签」与 8 个色板按钮都没有可访问名称，这里把当时缺的 9 个钉住。
void main() {
  Future<void> pump(WidgetTester tester, Widget page) async {
    final fixture = await TodoVisualFixture.create();
    addTearDown(fixture.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: fixture.container,
        child: MaterialApp(
          theme: ThemeData.light().copyWith(
            extensions: const [AppThemeExtension(AppColors.light)],
          ),
          home: page,
        ),
      ),
    );
    await tester.pump();
    // 这些页面的 loading 态是无限旋转的 CircularProgressIndicator，
    // pumpAndSettle 永远不会静止下来（会超时），所以只推进有限帧。
    await tester.pump(const Duration(milliseconds: 120));
  }

  testWidgets('标签页三个图标按钮都有可访问名称', (tester) async {
    await pump(tester, const TagPage());
    expect(find.byTooltip('新建标签'), findsOneWidget);
    // 夹具库里本来就有标签，行内的编辑/删除按钮会渲染出来。
    expect(find.byTooltip('编辑标签'), findsWidgets);
    expect(find.byTooltip('删除标签'), findsWidgets);
  });

  testWidgets('文件夹页与清单页的新建按钮有可访问名称', (tester) async {
    await pump(tester, const FolderPage());
    expect(find.byTooltip('新建文件夹'), findsOneWidget);

    await pump(tester, const ListPage());
    expect(find.byTooltip('新建清单'), findsWidgets);
  });

  testWidgets('习惯页新建按钮有可访问名称', (tester) async {
    await pump(tester, const HabitPage());
    expect(find.byTooltip('新建习惯'), findsOneWidget);
  });

  testWidgets('倒数纪念日页新建按钮有可访问名称', (tester) async {
    await pump(tester, const CountdownPage());
    expect(find.byTooltip('新建倒数纪念日'), findsOneWidget);
  });
}
