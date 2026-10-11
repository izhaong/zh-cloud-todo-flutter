import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/efficiency_api.dart';
import 'package:zh_cloud_todo_flutter/features/countdown/countdown_page.dart';
import 'package:zh_cloud_todo_flutter/state/efficiency_providers.dart';

/// 嘀嗒《02-功能指南/06-倒数纪念日/02-打造专属纪念页.md》：
/// 「挑选样式后，还可以为它配置专属颜色」与备注段「点击左下角的『备注』按钮，
/// 为这个日子添加一段文字记录」且带「在详情页中显示」开关。
/// 服务端契约见 service !348（specs/033-countdown-color-note）；本文件钉客户端接线（FL #546）。
const _listPath = '/todo/countdown/list';
const _createPath = '/todo/countdown/create';
const _updatePath = '/todo/countdown/update';

/// 记请求体的假服务：/list 返回种子行，create/update 收下并记录。
class _Server {
  _Server(this.rows);

  List<Map<String, dynamic>> rows;
  final List<RequestOptions> requests = [];

  RequestOptions? last(String suffix) {
    final hit = requests.where((r) => r.path.endsWith(suffix)).toList();
    return hit.isEmpty ? null : hit.last;
  }

  Dio dio() {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          final path = options.path;
          if (path.endsWith(_listPath)) {
            return handler.resolve(
              _ok(options, [
                for (final r in rows) Map<String, dynamic>.from(r),
              ]),
            );
          }
          return handler.resolve(_ok(options, true));
        },
      ),
    );
    return dio;
  }
}

Response<Map<String, dynamic>> _ok(RequestOptions options, dynamic data) {
  return Response<Map<String, dynamic>>(
    requestOptions: options,
    statusCode: 200,
    data: {'code': 0, 'data': data, 'msg': ''},
  );
}

Map<String, dynamic> _row({
  int id = 7,
  String? color,
  String? note,
  bool noteShowInDetail = false,
}) => {
  'id': id,
  'name': '发布日',
  'targetDate': '2026-12-31',
  'daysRemaining': 90,
  'style': 1,
  'showAge': false,
  'color': color,
  'note': note,
  'noteShowInDetail': noteShowInDetail,
};

Future<_Server> _pump(WidgetTester tester, _Server server) async {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        countdownApiProvider.overrideWithValue(CountdownApi(server.dio())),
      ],
      child: const MaterialApp(home: CountdownPage()),
    ),
  );
  await tester.pumpAndSettle();
  return server;
}

void main() {
  test('CountdownDto 解析颜色备注与详情开关，缺省给 null/null/false', () {
    final full = CountdownDto.fromJson(
      _row(color: '#FF6B6B', note: '每年都要一起过', noteShowInDetail: true),
    );
    expect(full.color, '#FF6B6B');
    expect(full.note, '每年都要一起过');
    expect(full.noteShowInDetail, isTrue);

    final bare = CountdownDto.fromJson(_row());
    expect(bare.color, isNull);
    expect(bare.note, isNull);
    expect(bare.noteShowInDetail, isFalse);
  });

  testWidgets('编辑器：选颜色、写备注、开「在详情页中显示」→ create 请求体三键齐', (tester) async {
    final server = await _pump(tester, _Server([]));
    await tester.tap(find.byTooltip('新建倒数纪念日'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('countdown-title-field')),
      '发布日',
    );
    await tester.tap(find.byKey(const Key('countdown-color-#FF6B6B')));
    await tester.enterText(
      find.byKey(const Key('countdown-note-field')),
      '每年都要一起过',
    );
    await tester.tap(find.byKey(const Key('countdown-note-show-in-detail')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('countdown-editor-save')));
    await tester.pumpAndSettle();

    final create = server.last(_createPath);
    expect(create, isNotNull);
    final body = create!.data as Map;
    expect(body['color'], '#FF6B6B');
    expect(body['note'], '每年都要一起过');
    expect(body['noteShowInDetail'], true);
  });

  testWidgets('编辑回显：已有颜色/备注/开关进编辑器，改颜色后 update 带新值', (tester) async {
    final server = await _pump(
      tester,
      _Server([_row(color: '#3B82F6', note: '旧备注', noteShowInDetail: true)]),
    );
    await tester.tap(find.byKey(const Key('countdown-edit-7')));
    await tester.pumpAndSettle();
    // 回显：备注文本与开关状态都来自该行自己的值。
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('countdown-note-field')))
          .controller!
          .text,
      '旧备注',
    );
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key('countdown-note-show-in-detail')),
          )
          .value,
      isTrue,
    );
    await tester.tap(find.byKey(const Key('countdown-color-#22C55E')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('countdown-editor-save')));
    await tester.pumpAndSettle();

    final update = server.last(_updatePath);
    expect(update, isNotNull);
    final body = update!.data as Map;
    expect(body['color'], '#22C55E');
    expect(body['note'], '旧备注');
    expect(body['noteShowInDetail'], true);
  });

  testWidgets('选「默认」清掉颜色，update 发空串而不是留着旧色', (tester) async {
    final server = await _pump(tester, _Server([_row(color: '#3B82F6')]));
    await tester.tap(find.byKey(const Key('countdown-edit-7')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('countdown-color-default')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('countdown-editor-save')));
    await tester.pumpAndSettle();

    final body = server.last(_updatePath)!.data as Map;
    expect(body['color'], '');
  });

  testWidgets('卡片：开关开着且备注非空才显示备注；颜色条用该行自己的色', (tester) async {
    await _pump(
      tester,
      _Server([
        _row(id: 7, color: '#FF6B6B', note: '每年都要一起过', noteShowInDetail: true),
        _row(id: 8, note: '不开关不显示', noteShowInDetail: false),
      ]),
    );

    expect(find.text('每年都要一起过'), findsOneWidget);
    expect(find.text('不开关不显示'), findsNothing);
    final strip = tester.widget<Container>(
      find.byKey(const Key('countdown-color-strip-7')),
    );
    expect(strip.color, const Color(0xFFFF6B6B));
    expect(find.byKey(const Key('countdown-color-strip-8')), findsNothing);
  });
}
