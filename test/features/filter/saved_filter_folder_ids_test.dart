import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zh_cloud_todo_flutter/features/filter/filter_bar.dart';
import 'package:zh_cloud_todo_flutter/features/filter/saved_filter_mapping.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/filter_repository.dart';

/// FL Issue #527：已保存过滤器要能存下、套出「文件夹」这一维。
/// 契约侧：zh-cloud-service `origin/develop@cedbf31eb0f4` 的 `TodoFilterConditionsDO.folderIds`
/// （值是**服务端**文件夹 id；条件顺序 `listIds, folderIds, tagIds, priorities, statuses, dateRange, keyword`）。
void main() {
  String jsonText(TaskFilter filter, Map<String, int> folderServerIds) =>
      jsonEncode(
        savedFilterOf(
          filter,
          folderServerIds: folderServerIds,
        ).conditions.toJson(),
      );

  group('写侧：本地文件夹主键映射成服务端 id', () {
    test('文件夹条件存得下：写成 folderIds 数组，值是服务端 id', () {
      final mapped = savedFilterOf(
        const TaskFilter(folderId: 'local-7'),
        folderServerIds: const {'local-7': 41},
      );

      expect(mapped.skipped, isEmpty);
      expect(mapped.conditions.folderIds, [41]);
    });

    test('还没同步上去的文件夹：拒绝保存并点名，不静默丢掉这一维', () {
      // 离线新建的文件夹没有服务端 id。存成「没有文件夹条件」等于替用户改条件，
      // 存成本地主键则别的端读不懂，且服务端会按未知 id 交集为空筛出空集。
      final mapped = savedFilterOf(
        const TaskFilter(folderId: 'local-7'),
        folderServerIds: const {},
      );

      expect(mapped.conditions.folderIds, isEmpty);
      expect(mapped.skipped, ['文件夹「local-7」还没同步到服务端']);
    });

    test('没有文件夹条件时不出键：改动前已存在的过滤器 JSON 一个字节都不变', () {
      expect(
        jsonText(const TaskFilter(priority: 3, keyword: '跨端'), const {}),
        '{"priorities":[3],"keyword":"跨端"}',
      );
    });

    test('文件夹索引还没就绪：点名成「稍后再试」而不是「这个文件夹没同步」', () {
      // foldersStreamProvider 还没发值时映射表是 null。把它当成「查不到」会给出误导的文案，
      // 用户以为文件夹没同步，其实是本机索引没到位。
      final mapped = savedFilterOf(
        const TaskFilter(folderId: 'local-7'),
        folderServerIds: null,
      );

      expect(mapped.skipped, ['文件夹条件：本机文件夹索引还没就绪，稍后再保存']);
      expect(mapped.conditions.folderIds, isEmpty);
    });
  });

  group('读侧：服务端 id 反查本地主键', () {
    test('单个 folderIds 能套回来', () {
      final restored = taskFilterFromSaved(
        TodoFilterConditions(folderIds: const [41]),
        unsupportedKeys: const {},
        folderLocalByServerId: const {41: 'local-7'},
      );

      expect(restored?.folderId, 'local-7');
    });

    test('多个文件夹套不回来：本机筛选态是单选，猜一个是替用户改条件', () {
      final restored = taskFilterFromSaved(
        TodoFilterConditions(folderIds: const [41, 42]),
        unsupportedKeys: const {},
        folderLocalByServerId: const {41: 'local-7', 42: 'local-8'},
      );

      expect(restored, isNull);
    });

    test('服务端 id 在本机找不到对应文件夹：不套，而不是套成「不限文件夹」', () {
      final restored = taskFilterFromSaved(
        TodoFilterConditions(folderIds: const [41]),
        unsupportedKeys: const {},
        folderLocalByServerId: const {},
      );

      expect(restored, isNull);
    });

    test('反查表没就绪时同样不套', () {
      final restored = taskFilterFromSaved(
        TodoFilterConditions(folderIds: const [41]),
        unsupportedKeys: const {},
        folderLocalByServerId: null,
      );

      expect(restored, isNull);
    });

    test('没有 folderIds 的老过滤器不受影响：还原结果与改动前同形', () {
      final restored = taskFilterFromSaved(
        TodoFilterConditions(listIds: const ['3'], priorities: const [2]),
        unsupportedKeys: const {},
        folderLocalByServerId: const {41: 'local-7'},
      );

      expect(restored?.folderId, isNull);
      expect(restored?.listId, '3');
      expect(restored?.priority, 2);
    });
  });

  group('契约对象的形状规矩', () {
    test('形状不对退回 unsupportedKeys，不读成空表', () {
      // 读成空表等于丢掉一条真实存在的条件（别的端可能存的是字符串数组或标量）。
      final parsed = TodoFilterConditions.fromJson(const {'folderIds': '41'});
      expect(parsed.unsupportedKeys, contains('folderIds'));
      expect(parsed.conditions.folderIds, isEmpty);

      final nested = TodoFilterConditions.fromJson(const {
        'folderIds': ['41'],
      });
      expect(nested.unsupportedKeys, contains('folderIds'));

      final fractional = TodoFilterConditions.fromJson(const {
        'folderIds': [41.5],
      });
      expect(fractional.unsupportedKeys, contains('folderIds'));
    });

    test('认得这个键：整数数组正常读出', () {
      final parsed = TodoFilterConditions.fromJson(const {
        'folderIds': [41, 42],
      });

      expect(parsed.unsupportedKeys, isEmpty);
      expect(parsed.conditions.folderIds, [41, 42]);
    });
  });

  group('摘要与连接词位置', () {
    test('摘要里看得见文件夹条件', () {
      expect(
        savedFilterSummary(
          TodoFilterConditions(folderIds: const [41, 42]),
          unsupportedKeys: const {},
        ),
        contains('文件夹 2 个'),
      );
    });

    test('folderIds 是第二条已启用条件：能挂连接词，第一条仍是 listIds', () {
      // 与新增的 CONDITION_ORDER 同源；面板的「条件之间」小节只有合法位置才给开关。
      expect(conditionOrder, [
        'listIds',
        'folderIds',
        'tagIds',
        'priorities',
        'statuses',
        'dateRange',
        'keyword',
      ]);
      expect(
        activeConditionKeys(
          const TaskFilter(listId: '3', folderId: 'local-7', keyword: '跨端'),
        ),
        ['listIds', 'folderIds', 'keyword'],
      );
      expect(conditionKeyLabel('folderIds'), '文件夹');
    });

    test('只勾文件夹时它是第一条：它的词会被放置校验点名拒绝', () {
      final mapped = savedFilterOf(
        const TaskFilter(
          folderId: 'local-7',
          keyword: '跨端',
          conditionLogics: {'folderIds': 'or'},
        ),
        folderServerIds: const {'local-7': 41},
      );

      expect(mapped.skipped, contains('跨条件逻辑词「folderIds」（它前面没有可连接的条件）'));
    });
  });
}
