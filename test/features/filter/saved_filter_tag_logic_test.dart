import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/features/filter/filter_bar.dart';
import 'package:zh_cloud_todo_flutter/features/filter/saved_filter_mapping.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/filter_repository.dart';

/// FL Issue #334 面 ①的第二刀：标签内「且/或」要能存进已保存过滤器、再忠实套回来。
///
/// 两条硬口径：
/// 1. **缺省不写键**。`TodoFilterConditions.toJson` 通篇是条件键（非默认才出），服务端
///    `TodoFilterServiceImpl:359-361` 又把「没有 tagLogic」当 AND ⇒ 「不写」与「写 and」等价，
///    老数据字节不变，不背兼容分支。
/// 2. **还原不出忠实条件就返回 null**（`saved_filter_mapping` 既有规矩）。套一个 or 过滤器却按 and
///    算，等于凭空改条件；未知逻辑词同理——不许猜。
void main() {
  TaskFilter filterWith(String logic) =>
      TaskFilter(tagIds: const ['t1', 't2'], tagLogic: logic);

  test('「或」档写进契约的 tagLogic，且值是服务端词表的小写 or', () {
    final mapped = savedFilterOf(filterWith(tagLogicOr));
    expect(mapped.conditions.tagLogic, tagLogicOr);
    expect(mapped.skipped, isEmpty);
    expect(jsonEncode(mapped.conditions.toJson()), contains('"tagLogic":"or"'));
  });

  test('缺省「且」不出键：老数据的 conditions JSON 一个字节都不变', () {
    final implicit = savedFilterOf(TaskFilter(tagIds: const ['t1', 't2']));
    final explicit = savedFilterOf(filterWith(tagLogicAnd));
    expect(implicit.conditions.toJson().containsKey('tagLogic'), isFalse);
    expect(explicit.conditions.toJson().containsKey('tagLogic'), isFalse);
    expect(
      jsonEncode(implicit.conditions.toJson()),
      jsonEncode(
        savedFilterOf(
          TaskFilter(tagIds: const ['t1', 't2']),
        ).conditions.toJson(),
      ),
    );
  });

  test('大写 OR 出仓前归一小写：出仓的每个 tagLogic 值都在词表内', () {
    // 服务端用 equalsIgnoreCase 认，但「同一份过滤器在别的客户端念成什么」不该靠运气；
    // 本仓其它出仓值（如 statuses 的 done/todo）也都是小写词表。
    expect(savedFilterOf(filterWith('OR')).conditions.tagLogic, tagLogicOr);
  });

  test('只有一个标签时不算「或」、也不写键：档位不能是一份界面上看不见也改不动的条件', () {
    // 单标签下 containsAll 与 any 命中集本就相同 ⇒ 求值不变；
    // 但界面上开关只在 ≥2 个标签时出现，留着 `or` 就落了一份「看不见、改不动」的条件。
    final single = savedFilterOf(
      TaskFilter(tagIds: const ['t1'], tagLogic: tagLogicOr),
    );
    expect(single.conditions.tagLogic, isNull);
    expect(single.conditions.toJson().containsKey('tagLogic'), isFalse);
    expect(
      taskFilterFromSaved(
        single.conditions,
        unsupportedKeys: const {},
      )!.tagsMatchAny,
      isFalse,
    );
  });

  test('fromJson 认识 tagLogic：不再把它当「契约装不下的键」', () {
    final parsed = TodoFilterConditions.fromJson(const {
      'tagIds': ['t1', 't2'],
      'tagLogic': 'or',
    });
    expect(parsed.unsupportedKeys, isNot(contains('tagLogic')));
    expect(parsed.conditions.tagLogic, 'or');
  });

  // 本条原先钉的是「conditionLogics 算不支持」——那是 #334 面 ② 没做时的诚实形状。
  // #524 把它做掉了（第二刀：`saved_filter_condition_logics_test.dart`），旧断言按定义作废，
  // 这里换成新的不变量：**读**侧不再因位置问题判死。
  test('读回来的跨条件词不丢：位置是否参与求值由服务端那条 i==0 规则决定，不在读侧提前判死', () {
    final parsed = TodoFilterConditions.fromJson(const {
      'tagIds': ['t1'],
      'priorities': [3],
      'conditionLogics': {'priorities': 'or'},
    });
    expect(parsed.unsupportedKeys, isNot(contains('conditionLogics')));
    final restored = taskFilterFromSaved(
      parsed.conditions,
      unsupportedKeys: parsed.unsupportedKeys,
    );
    expect(restored, isNotNull);
    expect(
      restored!.isConditionOr('priorities'),
      isTrue,
      reason: '词要原样带回来；它挂在 tagIds 之后，是合法位置',
    );
  });

  test('套回来时「或」不丢：还原出的 TaskFilter 仍是或档', () {
    final parsed = TodoFilterConditions.fromJson(const {
      'tagIds': ['t1', 't2'],
      'tagLogic': 'or',
    });
    final restored = taskFilterFromSaved(
      parsed.conditions,
      unsupportedKeys: parsed.unsupportedKeys,
    );
    expect(restored, isNotNull);
    expect(restored!.tagsMatchAny, isTrue);
  });

  test('服务端历史数据里的未知逻辑词不猜：按不支持套用', () {
    final parsed = TodoFilterConditions.fromJson(const {
      'tagIds': ['t1', 't2'],
      'tagLogic': 'xor',
    });
    expect(
      taskFilterFromSaved(
        parsed.conditions,
        unsupportedKeys: parsed.unsupportedKeys,
      ),
      isNull,
      reason: '「xor」既不是 and 也不是 or，套成任何一种都是凭空替用户做决定',
    );
  });
}
