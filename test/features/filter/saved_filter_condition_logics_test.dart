import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/features/filter/filter_bar.dart';
import 'package:zh_cloud_todo_flutter/features/filter/saved_filter_mapping.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/filter_repository.dart';

/// FL Issue #524（矩阵 #22 面 ⑥）第二刀：跨条件逻辑词要能存进 `todo_filter.conditions`、
/// 再忠实套回来。
///
/// 两条硬规矩都直接抄服务端（zh-cloud-service `origin/develop@7bd493dd1265`）：
/// 1. `TodoFilterServiceImpl.java:614-635` `validateLogicWords` —— 键必须在
///    `TodoFilterConditionsDO.CONDITION_ORDER` 里，值必须是 `and`/`or`（忽略大小写），否则整份拒绝。
/// 2. `TodoFilterServiceImpl.java:644-660` `validateLogicPlacement` —— 词只能挂在**已启用**的条件上，
///    且不能挂在**第一条已启用**条件上（它前面没有条件可连）；注释还点名「未启用条件的连接词
///    也不许静默丢掉」。
void main() {
  Map<String, dynamic> jsonOf(TaskFilter filter) =>
      jsonDecode(
            jsonEncode(
              savedFilterOf(
                filter,
                folderServerIds: const {},
              ).conditions.toJson(),
            ),
          )
          as Map<String, dynamic>;

  // 「一个字节都不变」这种主张只能拿字符串比字符串：jsonEncode 不转义中文，键序即 toJson 的书写序。
  String jsonText(TaskFilter filter) => jsonEncode(
    savedFilterOf(filter, folderServerIds: const {}).conditions.toJson(),
  );

  test('没有跨条件词时不出键：本轮改动前已存在的过滤器 JSON 一个字节都不变', () {
    expect(
      jsonText(const TaskFilter(priority: 3, keyword: '周报')),
      '{"priorities":[3],"keyword":"周报"}',
      reason: '连键的顺序都是形状的一部分，多出 conditionLogics 就不算"不变"',
    );
  });

  test('只挂「且」不出键：它是缺省连接词，写出去就改了老数据的形状', () {
    expect(
      jsonText(
        const TaskFilter(
          priority: 3,
          keyword: '跨端',
          conditionLogics: {'keyword': 'and'},
        ),
      ),
      '{"priorities":[3],"keyword":"跨端"}',
    );
  });

  test('合法的词原样出仓：挂在第二条已启用条件上', () {
    // 已启用：priorities → keyword；词挂 keyword ⇒ 合法（不是第一条）。
    final mapped = savedFilterOf(
      const TaskFilter(
        priority: 3,
        keyword: '周报',
        conditionLogics: {'keyword': 'or'},
      ),
      folderServerIds: const {},
    );
    expect(mapped.skipped, isEmpty, reason: '这条是合法形状，不该拦着用户保存');
    expect(mapped.conditions.conditionLogics, {'keyword': 'or'});
    expect(
      jsonText(
        const TaskFilter(
          priority: 3,
          keyword: '周报',
          conditionLogics: {'keyword': 'or'},
        ),
      ),
      '{"priorities":[3],"keyword":"周报","conditionLogics":{"keyword":"or"}}',
    );
  });

  test('词挂在第一条已启用条件上：点名给 UI，不静默丢掉（服务端会整份拒绝）', () {
    final mapped = savedFilterOf(
      const TaskFilter(
        priority: 3,
        keyword: '周报',
        conditionLogics: {'priorities': 'or'},
      ),
      folderServerIds: const {},
    );
    expect(
      mapped.skipped,
      isNotEmpty,
      reason: '「priorities」是第一条已启用条件，前面没有条件可连 ⇒ 写出去会被服务端拒绝',
    );
    expect(
      mapped.skipped.any((item) => item.contains('priorities')),
      isTrue,
      reason: '要点名到具体是哪一条，只说"存不住"用户没法改：${mapped.skipped}',
    );
  });

  test('词挂在没启用的条件上同样点名：取消勾选一条后残留的词不能悄悄扔', () {
    // 只启用了 priorities；词挂 tagIds ⇒ 服务端 validateLogicPlacement 判非法。
    final mapped = savedFilterOf(
      const TaskFilter(priority: 3, conditionLogics: {'tagIds': 'or'}),
      folderServerIds: const {},
    );
    expect(
      mapped.skipped.any((item) => item.contains('tagIds')),
      isTrue,
      reason: '「tagIds」这条现在根本没启用：${mapped.skipped}',
    );
  });

  test('一份词表里合法与非法并存时，非法那条要被单独点出来', () {
    final mapped = savedFilterOf(
      const TaskFilter(
        priority: 3,
        keyword: '周报',
        conditionLogics: {'priorities': 'or', 'keyword': 'or'},
      ),
      folderServerIds: const {},
    );
    expect(
      mapped.skipped.any((item) => item.contains('priorities')),
      isTrue,
      reason: '合法的 keyword 不该替非法的 priorities 遮过去：${mapped.skipped}',
    );
  });

  test('出仓值归一到词表小写：同一份过滤器在别的端念出来只有一个样子', () {
    expect(
      savedFilterOf(
        const TaskFilter(
          priority: 3,
          keyword: '周报',
          conditionLogics: {'keyword': 'OR'},
        ),
        folderServerIds: const {},
      ).conditions.conditionLogics,
      {'keyword': 'or'},
    );
  });

  test('fromJson 认识 conditionLogics：不再把它当「契约装不下的键」', () {
    final parsed = TodoFilterConditions.fromJson(const {
      'priorities': [3],
      'keyword': '周报',
      'conditionLogics': {'keyword': 'or'},
    });
    expect(parsed.unsupportedKeys, isNot(contains('conditionLogics')));
    expect(parsed.conditions.conditionLogics, {'keyword': 'or'});
  });

  test('套回来时词不丢：还原出的筛选态仍按「或」连接', () {
    final parsed = TodoFilterConditions.fromJson(const {
      'priorities': [3],
      'keyword': '周报',
      'conditionLogics': {'keyword': 'or'},
    });
    final restored = taskFilterFromSaved(
      parsed.conditions,
      unsupportedKeys: parsed.unsupportedKeys,
      folderLocalByServerId: const {},
    );
    expect(restored, isNotNull);
    expect(restored!.isConditionOr('keyword'), isTrue);
    expect(restored.isConditionOr('priorities'), isFalse);
  });

  test('值不在词表里整份拒套：不猜是 and 还是 or', () {
    final parsed = TodoFilterConditions.fromJson(const {
      'priorities': [3],
      'keyword': '周报',
      'conditionLogics': {'keyword': 'xor'},
    });
    expect(
      taskFilterFromSaved(
        parsed.conditions,
        unsupportedKeys: parsed.unsupportedKeys,
        folderLocalByServerId: const {},
      ),
      isNull,
      reason: '「xor」既不是 and 也不是 or（服务端 validateLogicWords 直接抛错）',
    );
  });

  test('键不在 CONDITION_ORDER 里整份拒套：那条条件本端不认', () {
    final parsed = TodoFilterConditions.fromJson(const {
      'priorities': [3],
      'keyword': '周报',
      'conditionLogics': {'assigneeUserId': 'or'},
    });
    expect(
      taskFilterFromSaved(
        parsed.conditions,
        unsupportedKeys: parsed.unsupportedKeys,
        folderLocalByServerId: const {},
      ),
      isNull,
      reason: '负责人在契约里存不下，挂在这个名字上的词无从解释',
    );
  });

  test('不是对象形状的 conditionLogics 仍旧算不支持（服务端同样抛错）', () {
    final parsed = TodoFilterConditions.fromJson(const {
      'priorities': [3],
      'keyword': '周报',
      'conditionLogics': 'or',
    });
    expect(
      parsed.unsupportedKeys,
      contains('conditionLogics'),
      reason: '读成空表等于把一条真实存在的条件丢掉',
    );
    expect(
      taskFilterFromSaved(
        parsed.conditions,
        unsupportedKeys: parsed.unsupportedKeys,
        folderLocalByServerId: const {},
      ),
      isNull,
    );
  });

  test('tagLogic 与 conditionLogics 各写各的键：一个是条件内部、一个是条件之间', () {
    final json = jsonOf(
      const TaskFilter(
        tagIds: ['t1', 't2'],
        tagLogic: 'or',
        priority: 3,
        keyword: '周报',
        conditionLogics: {'keyword': 'or'},
      ),
    );
    expect(json['tagLogic'], 'or');
    expect(json['conditionLogics'], {'keyword': 'or'});
  });

  test('只有条件、没有任何词时也不出空对象键（与服务端的 null 等价）', () {
    expect(
      jsonOf(const TaskFilter(priority: 3)).containsKey('conditionLogics'),
      isFalse,
    );
    expect(
      savedFilterOf(
        const TaskFilter(priority: 3, conditionLogics: {}),
        folderServerIds: const {},
      ).skipped,
      isEmpty,
      reason: '空表 = 没有跨条件词，不该拦保存',
    );
  });
}
