import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/features/collaboration/list_member_page.dart';
import 'package:zh_cloud_todo_flutter/features/shell/section.dart';
import 'package:zh_cloud_todo_flutter/features/shell/sidebar.dart';

import '../../support/todo_visual_fixture.dart';
import '../../support/todo_visual_test_harness.dart';

/// specs/053 清单动作表补「共享协作」（FL #359 / 矩阵 #52）。
///
/// 术语与路径照抄嘀嗒《07-共享与协作/01-如何共享清单.md》`:6`/`:8`；
/// 形态偏差（本仓清单级动作表在侧栏长按，不是清单详情右上角「···」）写在 spec 取舍 1。
class _TestSidebar extends StatelessWidget {
  const _TestSidebar();

  @override
  Widget build(BuildContext context) {
    // 侧栏在真机上永远位于某个 Scaffold 内；不套 Scaffold 时
    // ScaffoldMessenger.showSnackBar 会直接断言失败（本轮第一版就撞了这个）。
    return const Material(
      child: Scaffold(
        body: Sidebar(
          selectedSection: Section.tasks,
          selectedSmart: SmartList.inbox,
          selectedListId: null,
          onSelectSection: _noopSection,
          onSelectSmart: _noopSmart,
          onSelectList: _noopList,
          onOpenTags: _noopVoid,
          onOpenFilters: _noopVoid,
          onOpenSettings: _noopVoid,
          onOpenPomodoro: _noopVoid,
          onOpenHabit: _noopVoid,
          onOpenCountdown: _noopVoid,
        ),
      ),
    );
  }
}

void _noopSection(Section _) {}
void _noopSmart(SmartList _) {}
void _noopList(String? _) {}
void _noopVoid() {}

const _shareKey = Key('sidebar-list-action-share');
const _editKey = Key('sidebar-list-action-edit');
const _deleteKey = Key('sidebar-list-action-delete');

Future<TodoVisualFixture> _pump(
  WidgetTester tester, {
  Size? viewport,
  double textScale = 1,
}) async {
  // 字号档打在 platformDispatcher 上：动作表是 root Navigator 上的路由，
  // 包在 home 子树里的 MediaQuery 到不了它（specs/033 实测过的坑）。
  if (textScale != 1) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  return pumpTodoVisualScenario(
    tester,
    viewport: viewport ?? TodoVisualViewports.wide,
    fixtureSet: TodoVisualFixtureSet.populated,
    child: const Align(alignment: Alignment.topLeft, child: _TestSidebar()),
  );
}

Future<void> _openActions(WidgetTester tester, String listId) async {
  final row = find.byKey(ValueKey('todo-sidebar-list-$listId'));
  // scrollable 用整树第一个：与既有 sidebar_list_management_test 同一写法。
  // （先试了「限定在 todo-sidebar 内找 Scrollable」，在这套 harness 下 No element。）
  await tester.scrollUntilVisible(
    row,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.longPress(row);
  await tester.pumpAndSettle();
}

/// 把某条清单标成"已同步"（写了 serverId）。**必须断影响行数**：
/// 0 行时 drift 不报错，会让"已同步"这个前提静默不成立（记忆里踩过）。
Future<void> _markSynced(AppDatabase db, String listId, int serverId) async {
  final query = db.update(db.todoLists)..where((t) => t.id.equals(listId));
  final rows = await query.write(TodoListsCompanion(serverId: Value(serverId)));
  expect(rows, 1, reason: '用例前提不成立：清单 $listId 没被改成已同步');
}

void main() {
  testWidgets('清单动作表出现「共享协作」，排在「编辑」之后、「删除」之前', (tester) async {
    await _pump(tester);
    await _openActions(tester, TodoVisualFixture.personalListId);

    expect(find.byKey(_shareKey), findsOneWidget);
    expect(find.text('共享协作'), findsOneWidget);
    final edit = tester.getRect(find.byKey(_editKey)).top;
    final share = tester.getRect(find.byKey(_shareKey)).top;
    final delete = tester.getRect(find.byKey(_deleteKey)).top;
    expect(edit < share, isTrue, reason: '删除永远垫底是破坏性动作的约定，共享不能压过编辑');
    expect(share < delete, isTrue);
  });

  testWidgets('读屏：「共享协作」这一项 label 全等且是按钮', (tester) async {
    await _pump(tester);
    final handle = tester.ensureSemantics();
    try {
      await _openActions(tester, TodoVisualFixture.personalListId);
      final node = tester.getSemantics(find.byKey(_shareKey));
      expect(node.label, '共享协作');
      expect(node.flagsCollection.isButton, isTrue);
      expect(find.bySemanticsLabel('共享协作'), findsOneWidget);
    } finally {
      handle.dispose();
    }
  });

  testWidgets('已同步的清单点「共享协作」打开成员页，带的是这条清单', (tester) async {
    final fixture = await _pump(tester);
    await _markSynced(fixture.database, TodoVisualFixture.personalListId, 9001);
    // 不 pump 就是拿「改库前」那一行去点：serverId 仍是 null ⇒ 会走未同步分支，
    // 症状看起来像跳转坏了，实际是用例时序没给流推新值的机会。
    await tester.pumpAndSettle();
    await _openActions(tester, TodoVisualFixture.personalListId);

    await tester.tap(find.byKey(_shareKey));
    await tester.pumpAndSettle();

    final page = find.byType(ListMemberPage);
    expect(page, findsOneWidget);
    final pushed = tester.widget<ListMemberPage>(page);
    expect(pushed.listServerId, 9001, reason: '开的是这条清单的成员页，不是别的');
    expect(pushed.title, isNotNull, reason: '标题由清单名带来；成员页顶栏要能看出是哪个清单');
    // 顶栏把清单名拼在「协作成员」后面（`list_member_page.dart:183`
    // `'协作成员${widget.title != null ? ' · ${widget.title}' : ''}'`），
    // 不单独渲染一个 Text(清单名) ⇒ 断整串。原来断 find.text(标题本身) 是越界要求，
    // 红的原因是"我以为它会那样渲染"，不是"标题没带过去"（138 行那条已经证过数据）。
    expect(
      find.descendant(of: page, matching: find.text('协作成员 · ${pushed.title}')),
      findsOneWidget,
    );
  });

  testWidgets('清单还没同步时不跳转，给得出原因且不吞掉侧栏', (tester) async {
    await _pump(tester);
    await _openActions(tester, TodoVisualFixture.personalListId);

    await tester.tap(find.byKey(_shareKey));
    await tester.pumpAndSettle();

    expect(
      find.byType(ListMemberPage),
      findsNothing,
      reason: '没有 serverId 就推进去只会得到一个打不开空列表的页面',
    );
    expect(
      find.text('清单尚未同步，无法打开共享协作'),
      findsOneWidget,
      reason: '点了没反应是最糟的：要说得出为什么',
    );
    expect(find.byType(Sidebar), findsOneWidget, reason: '提示不能把用户已经打开的侧栏一起带走');
  });

  testWidgets('智能清单行压根没有长按动作表 ⇒ 「共享协作」结构上到不了它（嘀嗒 :6 的边界）', (tester) async {
    // 正对照在第 1 条用例（同 harness、同 fixture：真实清单行长按起得出动作表且含「共享协作」），
    // 这里不重复起第二棵树 —— 一个 test 里 pump 两次会同时持有两个 AppDatabase，
    // drift 直接打 WARNING（实测：`you've created the database class AppDatabase multiple times`）。
    // 也不复用"开完再关掉"的那棵树：在这套 harness 上关掉弹层后再找滚动容器，
    // 实测 `scrollUntilVisible` 抛 `Bad state: No element` ⇒ 在那棵树上断"没有弹层"，
    // 量到的是 harness 的巧合而不是机制。
    await _pump(tester);
    final inbox = find.byKey(const Key('todo-sidebar-row-inbox'));
    await tester.scrollUntilVisible(
      inbox,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(inbox, findsOneWidget);
    // ⚠️ 取"改动前"的快照**必须先 settle**：`scrollUntilVisible` 之后惯性滚动还在跑，
    // 没 settle 就数，数到的是动画中途的树 ⇒ 后面那条相等判据会假红（实测对照组就红了）。
    await tester.pumpAndSettle();
    // 负断言**按形态判，不按文案/图标判**（第 3 轮复核给出的教训）。
    // 前两版都是"列举形状"：`find.text` 只认恰好等于 ⇒ 放过 `Text('共享协作 · 邀请成员')`、
    // `SnackBar(Text('去共享协作'))`、`IconButton(icon: Icons.share)`；换成
    // `textContaining` + `byIcon(Icons.share)` 之后，复核员又量出**至少五种**仍逃逸的形状：
    // 裸 `RichText`（屏上真有那四个字，但 `find.textContaining` 默认 `findRichText:false` 看不见）、
    // `Icons.people_outline`（**正是本仓真入口自己用的图标**）、`Icons.share_outlined`、
    // 只给 `Semantics(label:)`、以及 `Image` 图标。⇒ 逐形枚举是追不完的。
    //
    // 所以这里断的是**结果**，分四件仪器 —— 每件都拿补丁量过射程与盲区（形状与读数记在
    // `specs/053-list-share-entry/tasks.md` 的 CX 表里），没有一条单独声称覆盖"任何形态"：
    //   ① ModalBarrier 数不变 ⇒ 拦自带屏障的三类：对话框、底部弹层、下拉菜单。第 4 轮复核点名的
    //      裸 `RichText`、`IconButton(Icons.share)`、`Icons.people_outline`、带 `Semantics(label:)`
    //      的对话框按钮、`PopupMenuItem(Icons.share_outlined)` 都在这里被咬住（实测 6 个形状）。
    //   ② 成员页与 SnackBar 都不出现 ⇒ 拦"整页 push"与"提示位"这两条 ① 之外还要给人话的入口。
    //   ③ 长按之后**整棵树的元素数一字不变** ⇒ 兜"不起路由、也不带屏障"那一族：
    //      `Overlay.insert` 的手写面板就是这种（第 4 轮复核实测它能躲过 ①②，红在 ③）。
    //      ③ 是**前后差**，所以看不见"静态就塞在那一行里"的东西 ⇒ 那一行由 ④ 钉。
    //   ④ 这一行的子树组件数 = 47（**相等**判据，不是差值）⇒ 多一个、少一个都会红（实测
    //      `Row(_Badge, Icon)` 47→54 红、`SizedBox.shrink` 47→42 红）。但**等量替换不一定看得见**：
    //      `trailing:` 整个换成一个 `Icon` 时 47 一动不动（实测仍绿），那一种由像素兜 ——
    //      同一个补丁在 `flutter test --tags golden` 下红 5/9 张。
    //      ⇒ ③④ 与像素基线是三张互补的网，各自的洞写在这段与 spec FR-4 的表里，不合并成一句话。
    // 机制（同一件事的另一面，写进 spec FR-4）：`sidebar.dart:91` 构造 `_SmartRow` 时只给 `onTap`
    // （类定义 `:448`，参数表里没有 `onLongPress`，build 也不向下传），动作表唯一调用点只挂在
    // 真实清单行 `:626` ⇒ 拿不到是**结构性**的，不是某条 if 拦住的；别读成"我们显式实现了 :6"。
    // 断言**顺序是故意的**：④ → ① → ② → ③。③ 数整棵树，放在前面会抢在 ①② 之前红，
    // 那两条就再也证不出自己有牙（实测过一次：顺序写错时七个浮层形状全部"红了但不在预期判据上"，
    // 见 tasks.md 的 CX 表下方那条自造缺陷）。
    // ④ 的作用域收在行键 `todo-sidebar-row-inbox` 上，不数整棵侧栏：那样任何无关的侧栏改动都会
    // 把它顶红，而这条只管这一行。③ 反过来**故意**数整棵树 —— 它是前后差，无关改动不会让它红。
    int rowWidgets() => tester
        .widgetList(
          find.descendant(
            of: inbox,
            matching: find.byWidgetPredicate((_) => true),
          ),
        )
        .length;
    final barriersBefore = find.byType(ModalBarrier).evaluate().length;
    // ③ 的基数：整棵树的元素数。必须在长按**之前**、且 settle 之后取。
    final treeBefore = tester.allWidgets.length;
    await tester.longPress(inbox);
    await tester.pumpAndSettle();
    // 绝对基线，不是"前后差"：静态塞进那一行的组件在 before/after 两张快照里都在，差值判据
    // 永远看不见它（上一版就是这么漏的）⇒ 只能钉住一个数。
    // 47 = develop 形态（这一轮没改实现）下该行子树的实测组件数；量法是把这里临时写成一个
    // 不可能的数（-1）、读失败输出的 Actual ⇒ 这个数不是抄来的，是同一棵树量出来的。
    expect(
      rowWidgets(),
      47,
      reason:
          '那一行的子树组件数不再是 develop 基线 47 ⇒ 这一行的结构被动过，而它只该在'
          '「给智能清单加了这个入口」时被动过（诚实边界：这是**相等**判据，等量替换不一定'
          '看得见，那一种由像素基线兜，见上面 ④）；确要改这一行的结构就改这个数并在 spec 说明',
    );
    expect(
      find.byType(ModalBarrier),
      findsNWidgets(barriersBefore),
      reason: '对话框/底部弹层/下拉菜单都自带屏障 ⇒ 按"有没有新浮层"判，不按文案与图标判',
    );
    expect(
      find.byType(ListMemberPage),
      findsNothing,
      reason: '无屏障的整页 push 不在 ModalBarrier 射程内，单独钉（复核第 3 轮的 ③）',
    );
    expect(find.byType(SnackBar), findsNothing, reason: 'SnackBar 也不许成为第二个入口');
    expect(
      tester.allWidgets.length,
      treeBefore,
      reason:
          '长按收集箱行之后整棵树的元素数变了 ⇒ 长按确实起了东西（哪怕是 '
          '`Overlay.insert` 这种不带路由、也不带屏障的手写面板 —— 第 4 轮复核实测它能躲过 ①②）',
    );
    // 下面两条是**次级**判据（钉的是"即便有浮层，也不许出现共享协作那四个字/那个图标"），
    // 不承担上界：`byIcon` 只认 `Icons.share` 那一个 codepoint，`textContaining` 默认不读 RichText。
    expect(
      find.textContaining('共享协作'),
      findsNothing,
      reason: '「今天」「明天」等智能清单以及「收集箱」不支持共享协作（嘀嗒 :6）',
    );
    expect(
      find.byIcon(Icons.share),
      findsNothing,
      reason: '只钉 Icons.share 这一个 codepoint；分享族其它图标与 RichText 由上面三条兜',
    );
    expect(find.text('编辑'), findsNothing, reason: '连「编辑」都没有 ⇒ 不是只把共享这一项筛掉了');
    expect(
      find.byType(BottomSheet),
      findsNothing,
      reason: '长按收集箱行起不出任何动作表 ⇒ 这一族根本没有清单级动作入口',
    );
    expect(find.byKey(_shareKey), findsNothing);
  });

  testWidgets('320px + 1.3：动作表三项在自己的 context 上都不越界', (tester) async {
    await _pump(tester, viewport: const Size(320, 568), textScale: 1.3);
    await _openActions(tester, TodoVisualFixture.personalListId);

    // 先确认最坏内容真在树里，再量几何。
    expect(find.text('共享协作'), findsOneWidget);
    // 档位自检取**文案**的 element，不取私有键：键名是内部契约，改个键名不该让
    // 「溢出量测」这条红（复核第 1 轮 X6 读数里 T6 的红是纯假警报，可见行为零变化）。
    expect(
      MediaQuery.textScalerOf(tester.element(find.text('共享协作'))).scale(10),
      closeTo(13, 0.001),
      reason: '档位没传到弹层自己的 context，量出来的溢出数字就没有意义',
    );
    expect(
      _flexOverflows(tester, find.byType(MaterialApp)),
      isEmpty,
      reason: '整棵树里任何横向/纵向 Flex 越界都算（含弹层自身）',
    );
    expect(tester.takeException(), isNull);
  });
}

/// 量整棵弹层子树里每个 RenderFlex 的子节点是否越出自身边界。
/// 不用 takeException() 当唯一判据（它取走并清空，多处只有第一次有断言力）。
List<String> _flexOverflows(WidgetTester tester, Finder scope) {
  final hits = <String>[];
  void walk(RenderObject node) {
    if (node is RenderFlex) {
      final horizontal = node.direction == Axis.horizontal;
      final bound = horizontal ? node.size.width : node.size.height;
      node.visitChildren((child) {
        if (child is! RenderBox || child.debugNeedsLayout) return;
        final data = child.parentData;
        if (data is! BoxParentData) return;
        final extent = horizontal
            ? data.offset.dx + child.size.width
            : data.offset.dy + child.size.height;
        if (extent > bound + 0.01) {
          hits.add(
            '${horizontal ? '横向' : '纵向'}越界 ${(extent - bound).toStringAsFixed(1)}px @ ${node.toStringShort()}',
          );
        }
      });
    }
    node.visitChildren(walk);
  }

  walk(tester.renderObject(scope));
  return hits;
}
