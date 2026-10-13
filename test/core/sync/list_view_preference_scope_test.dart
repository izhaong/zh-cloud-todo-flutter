import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/sync/list_view_preference_scope.dart';

/// 清单作用域偏好的键形状（FL #619）。
void main() {
  test('三种类型各自的本地形状都能取出清单 id', () {
    expect(
      ListViewPreferenceScope.localListId('task_view', 'list:list-a'),
      'list-a',
    );
    expect(
      ListViewPreferenceScope.localListId('TASK_SORT', 'list-a'),
      'list-a',
    );
    expect(
      ListViewPreferenceScope.localListId('TASK_GROUP', 'list-a'),
      'list-a',
    );
  });

  test('收集箱与设备无关的键不参与归一', () {
    expect(ListViewPreferenceScope.localListId('TASK_SORT', 'inbox'), isNull);
    expect(
      ListViewPreferenceScope.localListId('task_view', 'list:inbox'),
      isNull,
    );
  });

  test('形状不认识的键按原样发送，不当成"还没上服务端的清单"', () {
    // task_view 的历史遗留键没有 `list:` 前缀：它不是某台设备的清单 UUID，
    // 如果被误判成清单 id，出站会被整条丢掉（比脏键更糟：偏好再也不发）。
    expect(
      ListViewPreferenceScope.localListId('task_view', 'tasks_by_list'),
      isNull,
    );
    expect(ListViewPreferenceScope.localListId('task_view', 'list:'), isNull);
    expect(ListViewPreferenceScope.localListId('WEEK_START', 'global'), isNull);
    expect(ListViewPreferenceScope.localListId(null, 'list-a'), isNull);
    expect(ListViewPreferenceScope.localListId('task_view', null), isNull);
  });

  test('规范键与本地形状可以来回换算', () {
    expect(ListViewPreferenceScope.canonicalKey(101), 'list-server:101');
    expect(ListViewPreferenceScope.isCanonicalKey('list-server:101'), isTrue);
    expect(ListViewPreferenceScope.isCanonicalKey('list:list-a'), isFalse);
    expect(ListViewPreferenceScope.canonicalServerId('list-server:101'), 101);
    expect(
      ListViewPreferenceScope.canonicalServerId('list-server:abc'),
      isNull,
    );
    expect(
      ListViewPreferenceScope.localKey('task_view', 'list-a'),
      'list:list-a',
    );
    expect(ListViewPreferenceScope.localKey('TASK_SORT', 'list-a'), 'list-a');
    expect(ListViewPreferenceScope.localKey('UNKNOWN_TYPE', 'list-a'), isNull);
  });

  test('作用域集合只含这三类，越界的偏好类型一律不动', () {
    expect(ListViewPreferenceScope.isListScopedType('task_view'), isTrue);
    expect(ListViewPreferenceScope.isListScopedType('TASK_SORT'), isTrue);
    expect(ListViewPreferenceScope.isListScopedType('TASK_GROUP'), isTrue);
    for (final outside in const [
      'WEEK_START',
      'TASK_SWIPE',
      'TASK_CAPTURE',
      'TIMEZONE',
      'quadrant_view',
    ]) {
      expect(
        ListViewPreferenceScope.isListScopedType(outside),
        isFalse,
        reason: '$outside 不是"清单视图"这一族，归一不能顺手把它们卷进来',
      );
    }
  });
}
