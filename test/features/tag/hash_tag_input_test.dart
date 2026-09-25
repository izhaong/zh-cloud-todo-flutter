import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/features/tag/hash_tag_input.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/tag_repository.dart';

/// 嘀嗒《01-任务/08-如何管理海量任务/04-用标签管理任务.md》:48/:61
/// 「创建任务时输入「#」快速创建标签」——这一层钉的是"「#」这个词法到底解析出什么"，
/// 界面接线在 `test/features/shell/quick_add_hash_tag_test.dart`。
void main() {
  group('parseHashTagInput', () {
    test('「#名称」从正文里剥出来，正文剩下的就是标题', () {
      final draft = parseHashTagInput('写周报 #周会');
      expect(draft.title, '写周报');
      expect(draft.tagNames, ['周会']);
    });

    test('标签名以空白终止：后面的字回到正文', () {
      final draft = parseHashTagInput('#写周报 明天再谈');
      expect(draft.tagNames, ['写周报']);
      expect(draft.title, '明天再谈');
    });

    test('多个标签按出现顺序去重', () {
      final draft = parseHashTagInput('#a 任务 #b 收尾 #a');
      expect(draft.tagNames, ['a', 'b']);
      expect(draft.title, '任务 收尾');
    });

    test('单独一个 # 不是标签：保留原文，别把用户打的井号吃掉', () {
      final draft = parseHashTagInput('进度 50#');
      expect(draft.tagNames, isEmpty);
      expect(draft.title, '进度 50#');
    });

    test('## 开头不算标签（防止把 markdown 标题当成标签名）', () {
      final draft = parseHashTagInput('##草稿 待整理');
      expect(draft.tagNames, isEmpty);
      expect(draft.title, '##草稿 待整理');
    });

    test('井号在词中间不算标签：C# 这类正文不许被拆', () {
      final draft = parseHashTagInput('重构 C# 服务层');
      expect(draft.tagNames, isEmpty);
      expect(draft.title, '重构 C# 服务层');
    });

    test('整段只有标签 ⇒ 标题为空串（界面据此给可见提示，不静默早退）', () {
      final draft = parseHashTagInput('#周会 #评审');
      expect(draft.title, isEmpty);
      expect(draft.tagNames, ['周会', '评审']);
    });

    test('多行快速添加：整段解析一次，行结构留给 createBatch', () {
      final draft = parseHashTagInput('明天 8点复盘 #B1\n整理验收清单 #B1');
      expect(draft.tagNames, ['B1']);
      // 换行必须还在：createBatch 靠它切多条任务，剥标签不能顺手把两行并成一行。
      expect(draft.title, isNot(contains('#B1')));
      expect(
        draft.title.split('\n').where((line) => line.trim().isNotEmpty),
        hasLength(2),
      );
    });
  });

  group('resolveTagIdsByName', () {
    late AppDatabase db;
    late TagRepository tags;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      tags = TagRepository(db, SyncChangeQueue(db));
    });

    tearDown(() => db.close());

    test('已有同名就用它，不新建（重复输入 #专注 不会长出第二个专注）', () async {
      final focus = await tags.create(name: '专注');

      final ids = await resolveTagIdsByName(repo: tags, names: ['专注']);

      expect(ids, [focus.id]);
      expect(await tags.getAll(), hasLength(1));
    });

    test('没有就建，建完名字逐字一致', () async {
      final ids = await resolveTagIdsByName(repo: tags, names: ['周会']);

      final rows = await tags.getAll();
      expect(rows, hasLength(1));
      expect(rows.single.name, '周会');
      expect(ids, [rows.single.id]);
    });

    test('首尾空白不参与匹配，但存进去的名字是清理过的', () async {
      final created = await resolveTagIdsByName(repo: tags, names: ['  周会  ']);

      final rows = await tags.getAll();
      expect(rows.single.name, '周会');
      expect(created, [rows.single.id]);

      // 清理后再输入同一个名字 ⇒ 命中刚建的那条，不再建第二遍
      final again = await resolveTagIdsByName(repo: tags, names: ['周会']);
      expect(again, created);
      expect(await tags.getAll(), hasLength(1));

      // 反方向也要成：库里已有 '周会'，这次输入带首尾空白的 '  周会  '。
      // 少了这一半时，探针 PJ（把匹配改成拿未 trim 的原串比）全绿 ⇒ 说明原先只验过
      // "空白被清掉后存进去"，没验过"空白能被清掉后命中已有"。
      final withSpaces = await resolveTagIdsByName(
        repo: tags,
        names: ['  周会  '],
      );
      expect(withSpaces, created, reason: '带空白的输入又建了一条 ⇒ 同一个标签长出两行');
      expect(await tags.getAll(), hasLength(1));
    });

    test('大小写不折叠：iOS 与 ios 是两个标签（嘀嗒无此合并规则）', () async {
      final ids = await resolveTagIdsByName(repo: tags, names: ['iOS', 'ios']);

      expect(ids, hasLength(2));
      expect(
        (await tags.getAll()).map((tag) => tag.name),
        containsAll(['iOS', 'ios']),
      );
    });

    test('库里已有重名两行时取最早创建的那条，且不新建第三行', () async {
      final first = await tags.create(name: '周会');
      await Future<void>.delayed(const Duration(milliseconds: 2));
      final second = await tags.create(name: '周会');
      expect(first.id, isNot(second.id));

      final ids = await resolveTagIdsByName(repo: tags, names: ['周会']);

      expect(ids, [first.id], reason: 'getAll() 按 createdAt 升序 ⇒ 与标签页看到的先后一致');
      expect(await tags.getAll(), hasLength(2));
    });

    test('空名单不碰数据库（一次都不查）', () async {
      expect(await resolveTagIdsByName(repo: tags, names: const []), isEmpty);
    });
  });
}
