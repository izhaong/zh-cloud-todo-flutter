import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/features/shell/sidebar_hierarchy.dart';

void main() {
  test('stable hierarchy keeps nesting and shows malformed nodes once', () {
    const nodes = [
      _Node('child', 'root'),
      _Node('root', null),
      _Node('grandchild', 'child'),
      _Node('orphan', 'missing'),
      _Node('cycle-a', 'cycle-b'),
      _Node('cycle-b', 'cycle-a'),
    ];

    final flattened = flattenSidebarHierarchy(
      nodes,
      idOf: (node) => node.id,
      parentIdOf: (node) => node.parentId,
    );

    expect(flattened.map((entry) => entry.node.id).toSet(), {
      for (final node in nodes) node.id,
    });
    expect(flattened, hasLength(nodes.length));
    expect(flattened.singleWhere((entry) => entry.node.id == 'root').depth, 0);
    expect(flattened.singleWhere((entry) => entry.node.id == 'child').depth, 1);
    expect(
      flattened.singleWhere((entry) => entry.node.id == 'grandchild').depth,
      2,
    );
    expect(
      flattened.singleWhere((entry) => entry.node.id == 'orphan').depth,
      0,
    );
  });
}

class _Node {
  const _Node(this.id, this.parentId);
  final String id;
  final String? parentId;
}
