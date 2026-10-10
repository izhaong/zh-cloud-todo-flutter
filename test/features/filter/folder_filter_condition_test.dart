import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/features/filter/filter_bar.dart';
import 'package:zh_cloud_todo_flutter/features/task/tasks_by_list_page.dart';

/// FL Issue #333 的「文件夹」半边（即时筛选）。
///
/// 判据源（zh-cloud-docs 镜像《05-过滤器：随心所欲筛选你想看的任务.md》:50
/// 「按照清单名称、标签、日期等属性进行多维度筛选」；嘀嗒把文件夹定义为「清单的容器」）：
/// 按文件夹筛 = 只留「所属清单挂在该文件夹下」的任务。
///
/// 为什么条件用本地 folder 主键（String）而不是服务端 id（int）：
/// `TodoLists.folderLocalId` 才是本地关系列，`TodoFolders.serverId` 可空（离线建的文件夹
/// 还没有服务端 id），用 int 的话这类文件夹根本筛不了；同仓的 `TaskFilter.listId` 也是本地
/// String，口径一致。
///
/// 本轮只做即时求值与面板条件；已保存过滤器的文件夹持久化要等 zh-cloud-service 扩
/// `todo_filter.conditions`（`saved_filter_mapping.dart` 现在把「文件夹」列在 skipped 里，
/// 拒绝保存并在对话框点名），所以这里不碰持久化。
void main() {
  TodoTask task(String id, String listId) {
    final stamp = DateTime(2026, 10, 1);
    return TodoTask(
      id: id,
      listId: listId,
      title: id,
      completed: false,
      cancelled: false,
      priority: 0,
      isPinned: false,
      sortOrder: 0,
      allDay: false,
      fixedTimezone: false,
      timeMode: 0,
      updatedAt: stamp,
      createdAt: stamp,
    );
  }

  final tasks = [task('a', 'work'), task('b', 'home'), task('c', 'work')];
  final now = DateTime(2026, 10, 9, 10);

  // 清单 → 文件夹的归属索引：work 在「公司」，home 未归类（不在图里）。
  final listFolderIds = <String, String>{'work': 'folder-company'};

  test('文件夹条件参与求值：只留所属清单挂在该文件夹下的任务', () {
    final items = applyTaskFilter(
      tasks,
      const TaskFilter(folderId: 'folder-company'),
      null,
      now,
      listFolderIds: listFolderIds,
    );
    expect(items.map((t) => t.id), ['a', 'c']);
  });

  test('未归类的清单不命中任何文件夹条件（不是「放行」）', () {
    final items = applyTaskFilter(
      tasks,
      const TaskFilter(folderId: 'folder-other'),
      null,
      now,
      listFolderIds: listFolderIds,
    );
    expect(items, isEmpty);
  });

  test('离线建、还没有服务端 id 的文件夹同样能筛（条件不依赖 serverId）', () {
    final items = applyTaskFilter(
      tasks,
      const TaskFilter(folderId: 'folder-local-only'),
      null,
      now,
      listFolderIds: <String, String>{'home': 'folder-local-only'},
    );
    expect(items.map((t) => t.id), ['b']);
  });

  test('没有文件夹条件时，归属索引不得改变结果', () {
    final items = applyTaskFilter(
      tasks,
      const TaskFilter(),
      null,
      now,
      listFolderIds: listFolderIds,
    );
    expect(items.map((t) => t.id), ['a', 'b', 'c']);
  });
}
