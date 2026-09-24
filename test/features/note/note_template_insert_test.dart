import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/todo_api.dart';
import 'package:zh_cloud_todo_flutter/core/theme/app_theme.dart';
import 'package:zh_cloud_todo_flutter/features/note/note_page.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/note_repository.dart';

/// 嘀嗒《03-特色功能/11-笔记与摘要》「用模板高效记笔记」：
/// 「进入笔记详情页，点击『使用模板』…选中任意一个即可自动添加到笔记中」。
class _FakeApiClient extends ApiClient {
  _FakeApiClient({required this.onGet});

  /// 按路径返回一份响应；测试自己控制完成时机，用来造「过期响应后到」。
  final Future<Response<Map<String, dynamic>>> Function(String path) onGet;
  int calls = 0;
  final List<String> paths = [];

  @override
  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query}) async {
    calls++;
    paths.add(path);
    return onGet(path) as Future<Response<T>>;
  }
}

Response<Map<String, dynamic>> _ok(List<Map<String, dynamic>> data) =>
    Response<Map<String, dynamic>>(
      statusCode: 200,
      requestOptions: RequestOptions(path: '/app-api/todo/template/list-my'),
      data: {'code': 0, 'msg': '', 'data': data},
    );

void main() {
  group('模板 REST 客户端', () {
    test('listMy 与 listPublic 各自打既有 app-api 路径，并按 wire 形状解包', () async {
      final client = _FakeApiClient(
        onGet: (path) async => _ok([
          {
            'id': path.endsWith('list-public') ? 90 : 7,
            'name': path.endsWith('list-public') ? '会议纪要' : '我的周报',
            'content': path.endsWith('list-public') ? '## 议题\n' : '## 本周\n',
            'templateType': 2,
            'isPublic': path.endsWith('list-public'),
          },
        ]),
      );
      final api = TemplateApi(client);

      final mine = await api.listMy();
      final presets = await api.listPublic();

      expect(
        client.paths,
        ['/template/list-my', '/template/list-public'],
        reason: '契约已存在（AppTodoSummaryAndTemplateController :47/:53），不许自己编路径',
      );
      expect(mine.single.name, '我的周报');
      expect(mine.single.content, '## 本周\n');
      expect(presets.single.id, 90);
      expect(
        presets.single.isPublic,
        isTrue,
        reason: '分组靠服务端给的 isPublic，不靠"哪个接口返回的"猜',
      );
    });

    test('code != 0 抛出并带服务端文案', () async {
      final client = _FakeApiClient(
        onGet: (path) async => Response<Map<String, dynamic>>(
          statusCode: 200,
          requestOptions: RequestOptions(path: path),
          data: {'code': 100500, 'msg': '模板服务暂不可用'},
        ),
      );
      await expectLater(
        TemplateApi(client).listMy(),
        throwsA(
          predicate((Object? e) => e is Exception && '$e'.contains('模板服务暂不可用')),
        ),
        reason: '失败要说得出原因，不能退化成空列表',
      );
    });
  });

  group('笔记编辑器「使用模板」', () {
    testWidgets('新建笔记里有「使用模板」入口', (tester) async {
      await _pumpNote(tester, onGet: _templates);
      await tester.tap(find.byKey(const Key('todo-note-add')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('todo-note-insert-template')),
        findsOneWidget,
        reason: '嘀嗒把入口放在笔记详情页，不在清单页也不在设置页',
      );
      expect(find.text('使用模板'), findsOneWidget);
    });

    testWidgets('弹层按「我的模板 / 预设模板」两组列出，选中即把正文插到光标处', (tester) async {
      await _pumpNote(tester, onGet: _templates);
      await tester.tap(find.byKey(const Key('todo-note-add')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('todo-note-insert-template')));
      await tester.pumpAndSettle();

      expect(find.text('我的模板'), findsOneWidget);
      expect(find.text('预设模板'), findsOneWidget);
      expect(find.text('我的周报'), findsOneWidget);
      expect(find.text('会议纪要'), findsOneWidget);

      // 光标停在正文中间，验证插的是光标处而不是末尾。
      final content = find.byKey(const Key('todo-note-content'));
      await tester.enterText(content, '前前后后');
      await tester.pump();
      final controller = tester.widget<TextField>(content).controller!;
      controller.selection = const TextSelection.collapsed(offset: 2);
      await tester.pump();

      await tester.tap(find.text('会议纪要'));
      await tester.pumpAndSettle();

      final after = tester.widget<TextField>(content).controller!.text;
      expect(
        after,
        '前前\n## 议题\n\n后后',
        reason: '整块插到光标处：Markdown 块前后要各占一行，且不许把用户已写的尾巴挤到模板后面',
      );
      expect(find.text('会议纪要'), findsNothing, reason: '插完就该关掉选择层');
    });

    testWidgets('刷新失败保留已加载列表并给出原因', (tester) async {
      var failNext = false;
      await _pumpNote(
        tester,
        onGet: (path) async {
          if (failNext) {
            return Response<Map<String, dynamic>>(
              statusCode: 200,
              requestOptions: RequestOptions(path: path),
              data: {'code': 100500, 'msg': '模板服务暂不可用'},
            );
          }
          return _templates(path);
        },
      );
      await tester.tap(find.byKey(const Key('todo-note-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('todo-note-insert-template')));
      await tester.pumpAndSettle();
      expect(find.text('我的周报'), findsOneWidget);

      failNext = true;
      await tester.tap(find.byKey(const Key('note-template-reload')));
      await tester.pumpAndSettle();

      expect(
        find.text('我的周报'),
        findsOneWidget,
        reason: '四件套之一：拉取失败不许把已经看到的列表清成空态',
      );
      expect(find.textContaining('模板服务暂不可用'), findsOneWidget);
    });

    testWidgets('后到的旧响应不得覆盖新结果', (tester) async {
      final stalled = Completer<Response<Map<String, dynamic>>>();
      var call = 0;
      await _pumpNote(
        tester,
        onGet: (path) async {
          call++;
          // 第一次加载的两个请求都卡住（listMy + listPublic），随后 reload 的那轮先完成。
          if (call <= 2) return stalled.future;
          return _ok([
            if (path.endsWith('list-my'))
              {
                'id': 3,
                'name': '最新模板',
                'content': '最新\n',
                'templateType': 2,
                'isPublic': false,
              }
            else
              {
                'id': 4,
                'name': '最新预设',
                'content': '最新预设\n',
                'templateType': 1,
                'isPublic': true,
              },
          ]);
        },
      );
      await tester.tap(find.byKey(const Key('todo-note-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('todo-note-insert-template')));
      // 弹层入场动画没走完时它在屏幕下方，点了也点不到；先把它推完。
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byKey(const Key('note-template-reload')));
      // 这里不能 pumpAndSettle：第一轮还挂着，进度指示器是无限动画，settle 永远不会回来。
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.text('最新模板'), findsOneWidget);

      stalled.complete(
        _ok([
          {
            'id': 1,
            'name': '过期模板',
            'content': '过期\n',
            'templateType': 2,
            'isPublic': false,
          },
        ]),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('过期模板'),
        findsNothing,
        reason: '按发起序号丢弃过期响应，否则用户看到的列表会退回上一次',
      );
      expect(find.text('最新模板'), findsOneWidget);
    });

    testWidgets('320px + 1.3 倍字体下长模板名不溢出', (tester) async {
      await _pumpNote(
        tester,
        textScale: 1.3,
        onGet: (path) async => _ok(
          path.endsWith('list-my')
              ? [
                  {
                    'id': 1,
                    'name': '每周工作总结与复盘模板超长名称超长名称超长名称',
                    'content': '## 本周\n',
                    'templateType': 2,
                    'isPublic': false,
                  },
                ]
              : const [],
        ),
      );
      await tester.tap(find.byKey(const Key('todo-note-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('todo-note-insert-template')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final name = find.text('每周工作总结与复盘模板超长名称超长名称超长名称');
      expect(name, findsOneWidget);
      expect(
        tester.getRect(name).right,
        lessThanOrEqualTo(320),
        reason: '名字再长也只能在弹层内换行/省略，不许顶出视口',
      );
    });

    testWidgets('入口、分组名与模板名都有独立读屏语义', (tester) async {
      await _pumpNote(tester, onGet: _templates);
      final handle = tester.ensureSemantics();
      try {
        // ensureSemantics 之后必须再走一帧，否则语义节点还没生成。
        await tester.pump();
        expect(
          find.bySemanticsLabel(RegExp(r'^使用模板$')),
          findsNothing,
          reason: '入口在笔记编辑器里，列表页不该有',
        );

        await tester.tap(find.byKey(const Key('todo-note-add')));
        await tester.pumpAndSettle();
        expect(
          find.bySemanticsLabel(RegExp(r'^使用模板$')),
          findsOneWidget,
          reason: '读屏用户要能单独找到这个动作',
        );

        await tester.tap(find.byKey(const Key('todo-note-insert-template')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(
          find.bySemanticsLabel(RegExp(r'^我的模板$')),
          findsOneWidget,
          reason: '分组口径不能只有视觉缩进',
        );
        expect(find.bySemanticsLabel(RegExp(r'^预设模板$')), findsOneWidget);
        expect(
          find.bySemanticsLabel(RegExp(r'^我的周报$')),
          findsOneWidget,
          reason: 'ListTile 只有标题时语义 label 就是模板名，点读要念得出选中什么',
        );
      } finally {
        handle.dispose();
      }
    });
  });
}

Future<Response<Map<String, dynamic>>> _templates(String path) async => _ok([
  if (path.endsWith('list-my'))
    {
      'id': 7,
      'name': '我的周报',
      'content': '## 本周\n',
      'templateType': 2,
      'isPublic': false,
    }
  else
    {
      'id': 90,
      'name': '会议纪要',
      'content': '## 议题\n',
      'templateType': 2,
      'isPublic': true,
    },
]);

Future<void> _pumpNote(
  WidgetTester tester, {
  required Future<Response<Map<String, dynamic>>> Function(String path) onGet,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = Size(320, 720);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(_FakeApiClient(onGet: onGet)),
        noteRepositoryProvider.overrideWithValue(_FakeNoteRepository()),
      ],
      child: MaterialApp(
        theme: ThemeData(
          extensions: const [AppThemeExtension(AppColors.light)],
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const NotePage(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

class _FakeNoteRepository implements NoteRepository {
  @override
  Future<List<TodoNoteItem>> list() async => const [];

  @override
  Future<int> create({required String title, required String content}) async =>
      1;

  @override
  Future<void> update({
    required int id,
    required String title,
    required String content,
    int sortOrder = 0,
  }) async {}

  @override
  Future<void> delete(int id) async {}

  @override
  Future<void> archive(int id, {required bool archived}) async {}

  @override
  Future<int> convertFromTask(int taskId) async => 1;
}
