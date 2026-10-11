import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart'
    show TodoFolder, TodoList;
import 'package:zh_cloud_todo_flutter/features/shell/sidebar_hierarchy.dart';
import 'package:zh_cloud_todo_flutter/state/providers.dart';

/// 文件夹筛选按「子树」求值的客户端那一半（与 zh-cloud-service Issue #344 同一口径，
/// 服务端台账 `specs/030-folder-descendant-folder/` 的 FL 对应面）。
///
/// 为什么两边必须一起改：服务端把 `folderIds` 展开成「种子 ∪ 子孙」之后，
/// 如果本地即时筛选还按直属算，同一个父文件夹条件就会给出两套答案
/// —— 列表与「预览命中数」都读这一份索引，所以索引必须自带祖先。
void main() {
  final stamp = DateTime(2026, 10, 11);

  TodoList list(String id, {String? folderLocalId}) => TodoList(
        id: id,
        name: id,
        folderLocalId: folderLocalId,
        sortOrder: 0,
        isPinned: false,
        accessRole: 'owner',
        writable: true,
        updatedAt: stamp,
        createdAt: stamp,
      );

  TodoFolder folder(String id, {String? parentId}) => TodoFolder(
        id: id,
        name: id,
        parentId: parentId,
        sortOrder: 0,
        updatedAt: stamp,
        createdAt: stamp,
      );

  group('folderAndAncestors：清单所在文件夹要连同全部祖先', () {
    test('三层链：孙级的清单同时属于子与父', () {
      const parentOf = {'root': null, 'mid': 'root', 'leaf': 'mid'};

      expect(folderAndAncestors('leaf', parentOf), {'leaf', 'mid', 'root'});
    });

    test('父链走到断点就停：未知 id 原样留着，不猜也不丢', () {
      const parentOf = {'leaf': 'ghost'};

      expect(folderAndAncestors('leaf', parentOf), {'leaf', 'ghost'});
    });

    test('脏数据成环也要终止（validateParent 挡新增边，挡不住历史脏数据）', () {
      const parentOf = {'a': 'b', 'b': 'a'};

      expect(folderAndAncestors('a', parentOf), {'a', 'b'});
    });
  });

  group('listFolderIndexProvider：图没就位时宁可等，也不给一张「只算直属」的图', () {
    test('清单发过值、文件夹还没发值 ⇒ 索引算没就位（返回 null 而不是空图）', () async {
      // 只按直属算的那张图会在筛选里被当成「已就位」，于是父文件夹条件读出零命中——
      // 那正是本轮要修的静默少给，所以这里必须让调用方去等。
      final container = ProviderContainer(
        overrides: [
          listsStreamProvider.overrideWith(
            (ref) => Stream<List<TodoList>>.value(const []),
          ),
          foldersStreamProvider.overrideWith(
            (ref) => const Stream<List<TodoFolder>>.empty(),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(listsStreamProvider.future);

      expect(container.read(listFolderIndexProvider), isNull);
    });

    test('两边都发过值但清单为空 ⇒ 给空图而不是 null（否则带文件夹条件的人一直转圈）', () async {
      final container = ProviderContainer(
        overrides: [
          listsStreamProvider.overrideWith(
            (ref) => Stream<List<TodoList>>.value(const []),
          ),
          foldersStreamProvider.overrideWith(
            (ref) => Stream<List<TodoFolder>>.value(const []),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(listsStreamProvider.future);
      await container.read(foldersStreamProvider.future);

      expect(container.read(listFolderIndexProvider), isEmpty);
    });

    test('清单挂在子文件夹：索引要同时带上子与父（父条件才能命中）', () async {
      final container = ProviderContainer(
        overrides: [
          listsStreamProvider.overrideWith(
            (ref) => Stream<List<TodoList>>.value(
              [list('list-in-leaf', folderLocalId: 'leaf')],
            ),
          ),
          foldersStreamProvider.overrideWith(
            (ref) => Stream<List<TodoFolder>>.value(
              [
                folder('root'),
                folder('mid', parentId: 'root'),
                folder('leaf', parentId: 'mid'),
                folder('elsewhere'),
              ],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(listsStreamProvider.future);
      await container.read(foldersStreamProvider.future);

      final index = container.read(listFolderIndexProvider);

      expect(index, isNotNull);
      expect(index!['list-in-leaf'], {'leaf', 'mid', 'root'});
      // 不在任何清单上的文件夹不该凭空出现在索引里，正对照是上面那条真的带上了祖先。
      expect(index.containsKey('elsewhere'), isFalse);
    });

    test('没有文件夹归属的清单不进索引（未归类不等于「属于某个文件夹」）', () async {
      final container = ProviderContainer(
        overrides: [
          listsStreamProvider.overrideWith(
            (ref) => Stream<List<TodoList>>.value([list('loose')]),
          ),
          foldersStreamProvider.overrideWith(
            (ref) => Stream<List<TodoFolder>>.value([folder('root')]),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(listsStreamProvider.future);
      await container.read(foldersStreamProvider.future);

      expect(container.read(listFolderIndexProvider), isEmpty);
    });
  });
}
