import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/features/habit/habit_editor.dart';
import 'package:zh_cloud_todo_flutter/features/habit/habit_repository.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';

/// specs/132 · 习惯级「打卡日志」开关（矩阵 #45 面 ④ 收尾）。
///
/// 判据源《02-更好地完成习惯.md》:60-:62——
/// 「在『编辑习惯』中底部，可以将打卡日志关闭」。
void main() {
  group('HabitDto.journalEnabled 序列化', () {
    test('缺省 true；显式 false 透传；旧数据无键按开启', () {
      expect(
        HabitDto.fromJson({
          'id': 1,
          'name': '习惯',
          'recordType': 1,
        }).journalEnabled,
        isTrue,
        reason: '旧数据无键按开启（读侧 null→true 兼容存量行）',
      );
      expect(
        HabitDto.fromJson({
          'id': 1,
          'name': '习惯',
          'recordType': 1,
          'journalEnabled': false,
        }).journalEnabled,
        isFalse,
      );
    });

    test('ctor 缺省 true', () {
      expect(HabitDto(id: 1, name: '习惯', recordType: 1).journalEnabled, isTrue);
    });
  });

  group('编辑器「打卡日志」开关（widget 级）', () {
    testWidgets('编辑器底部有「打卡日志」开关，默认开、可关（状态交互）', (tester) async {
      tester.view.physicalSize = const Size(390, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pumpEditorSheet(tester);

      final toggle = find.byKey(const Key('habit-editor-journal-toggle'));
      expect(toggle, findsOneWidget);

      // 默认开。
      expect(tester.widget<SwitchListTile>(toggle).value, isTrue);

      // 关掉。
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    });
  });
}

Future<void> _pumpEditorSheet(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: const [AppThemeExtension(AppColors.light)]),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showHabitEditor(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}
