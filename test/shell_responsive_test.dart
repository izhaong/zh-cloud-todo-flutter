import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/shell/section.dart';
import 'package:zh_cloud_todo_flutter/features/shell/sidebar.dart';

/// Phase 1 行为验证：
/// - Section / SmartList 枚举文案与图标
/// - Sidebar 智能清单 / 导航 / 清单树渲染 + 回调
void main() {
  group('Section 枚举', () {
    test('4 个分区文案', () {
      expect(Section.values.map((s) => s.label).toList(), [
        '任务',
        '日历',
        '习惯',
        '我的',
      ]);
    });
    test('每个分区都有图标', () {
      for (final s in Section.values) {
        expect(s.icon, isNotNull);
      }
    });
  });

  group('SmartList 枚举', () {
    test('6 个智能清单文案', () {
      expect(SmartList.values.map((s) => s.label).toList(), [
        '收件箱',
        '今天',
        '最近7天',
        '全部',
        '已完成',
        '垃圾桶',
      ]);
    });
  });

  group('Sidebar 渲染', () {
    testWidgets('渲染智能清单与浏览入口', (tester) async {
      var tapped = '';
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData.light().copyWith(
              extensions: const [AppThemeExtension(AppColors.light)],
            ),
            home: _TestSidebar(onSelectSmart: (s) => tapped = s.label),
          ),
        ),
      );
      // 智能清单
      expect(find.text('智能清单'), findsOneWidget);
      expect(find.text('收件箱'), findsOneWidget);
      expect(find.text('今天'), findsOneWidget);
      expect(find.text('最近7天'), findsOneWidget);
      expect(find.text('全部'), findsOneWidget);
      expect(find.text('已完成'), findsOneWidget);
      expect(find.text('垃圾桶'), findsOneWidget);
      // 浏览入口
      expect(find.text('浏览'), findsOneWidget);
      expect(find.text('日历'), findsOneWidget);
      expect(find.text('标签'), findsOneWidget);
      expect(find.text('筛选器'), findsOneWidget);
      // 清单树
      expect(find.text('清单'), findsOneWidget);
      expect(find.text('新建清单'), findsOneWidget);
      // 设置
      expect(find.text('设置'), findsOneWidget);

      // 点击智能清单触发回调
      await tester.tap(find.text('今天'));
      expect(tapped, '今天');
    });
  });
}

/// 用最小参数渲染真实 [Sidebar]（不依赖 provider 数据通路的字段给空 list）。
class _TestSidebar extends StatelessWidget {
  const _TestSidebar({required this.onSelectSmart});
  final ValueChanged<SmartList> onSelectSmart;

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Sidebar(
        selectedSection: Section.tasks,
        selectedSmart: SmartList.inbox,
        selectedListId: null,
        onSelectSection: (_) {},
        onSelectSmart: onSelectSmart,
        onSelectList: (_) {},
        onOpenTags: () {},
        onOpenFilters: () {},
        onOpenSettings: () {},
      ),
    );
  }
}
