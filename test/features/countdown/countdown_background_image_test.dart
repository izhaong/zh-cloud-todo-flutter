import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/efficiency_api.dart';
import 'package:zh_cloud_todo_flutter/features/countdown/countdown_page.dart';
import 'package:zh_cloud_todo_flutter/state/efficiency_providers.dart';

/// 嘀嗒《02-功能指南/06-倒数纪念日/02-打造专属纪念页.md》「自定义图片」：
/// mobile「选择图片样式后，切换到「图片」选项，即可替换图片或者上传心仪的背景图」；
/// desktop「在样式编辑窗口，点击「切换图片」，可以上传新的背景图片」。
/// 术语固定为「背景图」，不自创「封面」。本端只做消费面（服务端已有
/// `background_image` 列与 create/update 写入），上传面另判。
void main() {
  Future<void> pump(
    WidgetTester tester,
    List<CountdownDto> items, {
    Size? surface,
    double textScale = 1,
  }) async {
    if (surface != null) {
      await tester.binding.setSurfaceSize(surface);
      addTearDown(() => tester.binding.setSurfaceSize(null));
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          countdownsProvider.overrideWith((ref) => Future.value(items)),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: const CountdownPage(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  CountdownDto item({
    required int id,
    required String title,
    required int days,
    String? backgroundImage,
  }) {
    return CountdownDto(
      id: id,
      title: title,
      targetDate: DateTime(2026, 1, 1).add(Duration(days: days)),
      daysRemaining: days,
      showAge: true,
      backgroundImage: backgroundImage,
    );
  }

  testWidgets('带背景图的卡片渲染那张网络图，标题与天数都还在', (tester) async {
    await pump(tester, [
      item(
        id: 1,
        title: '上线',
        days: 30,
        backgroundImage: 'https://cdn.example.com/bg-1.jpg',
      ),
    ]);

    final image = find.byKey(const Key('countdown-background-1'));
    expect(image, findsOneWidget, reason: '服务端给了 backgroundImage 却不画 = 这列是摆设');
    final widget = tester.widget<Image>(image);
    final provider = widget.image;
    expect(provider, isA<NetworkImage>());
    expect(
      (provider as NetworkImage).url,
      'https://cdn.example.com/bg-1.jpg',
      reason: '画的必须是这一条记录自己的背景图',
    );
    expect(find.text('上线'), findsOneWidget);
    expect(find.text('还有 30 天'), findsOneWidget);
  });

  testWidgets('没有背景图时不冒名画一张', (tester) async {
    await pump(tester, [item(id: 2, title: '生日', days: 100)]);

    expect(find.byKey(const Key('countdown-background-2')), findsNothing);
    expect(find.text('生日'), findsOneWidget);
  });

  testWidgets('背景图取不到时不吞掉已加载的标题与天数', (tester) async {
    await pump(tester, [
      item(
        id: 3,
        title: '纪念日',
        days: 7,
        backgroundImage: 'https://cdn.example.com/missing.jpg',
      ),
    ]);

    expect(
      tester.takeException(),
      isNull,
      reason: '取图失败要经 errorBuilder 收敛，不能抛穿',
    );
    expect(find.text('纪念日'), findsOneWidget);
    expect(find.text('还有 7 天'), findsOneWidget);
  });

  testWidgets('320 宽与 1.3 倍字号下背景图与文字同屏不炸', (tester) async {
    await pump(
      tester,
      [
        item(
          id: 4,
          title: '很长的名字很长的名字很长的名字',
          days: 1095,
          backgroundImage: 'https://cdn.example.com/bg-4.jpg',
        ),
      ],
      surface: const Size(320, 640),
      textScale: 1.3,
    );

    expect(find.byKey(const Key('countdown-background-4')), findsOneWidget);
    expect(tester.takeException(), isNull);
    final rect = tester.getRect(find.byKey(const Key('countdown-row-4')));
    expect(rect.width, lessThanOrEqualTo(320));
  });
}
