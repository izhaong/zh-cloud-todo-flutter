import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/shell/section.dart';
import 'package:zh_cloud_todo_flutter/features/shell/sidebar.dart';

void main() {
  testWidgets('Sidebar 渲染 TickTick 风格分组与词汇', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData.dark().copyWith(
            extensions: const [AppThemeExtension(AppColors.dark)],
          ),
          home: const _TestSidebar(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('TickTick 风格工作台'), findsOneWidget);
    expect(find.text('智能清单'), findsOneWidget);
    expect(find.text('收件箱'), findsOneWidget);
    expect(find.text('今天'), findsOneWidget);
    expect(find.text('最近7天'), findsOneWidget);
    expect(find.text('全部'), findsOneWidget);
    expect(find.text('已完成'), findsOneWidget);
    expect(find.text('垃圾桶'), findsOneWidget);
    expect(find.text('浏览'), findsOneWidget);
    expect(find.text('日历'), findsOneWidget);
    expect(find.text('标签'), findsOneWidget);
    expect(find.text('筛选器'), findsOneWidget);
    expect(find.text('清单'), findsOneWidget);
    expect(find.text('新建清单'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });
}

class _TestSidebar extends StatelessWidget {
  const _TestSidebar();

  @override
  Widget build(BuildContext context) {
    return const Material(
      child: Sidebar(
        selectedSection: Section.tasks,
        selectedSmart: SmartList.inbox,
        selectedListId: null,
        onSelectSection: _noopSection,
        onSelectSmart: _noopSmart,
        onSelectList: _noopList,
        onOpenTags: _noopVoid,
        onOpenFilters: _noopVoid,
        onOpenSettings: _noopVoid,
      ),
    );
  }
}

void _noopSection(Section _) {}
void _noopSmart(SmartList _) {}
void _noopList(String? _) {}
void _noopVoid() {}
