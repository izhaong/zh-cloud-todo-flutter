import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/features/task/tasks_by_list_page.dart';

void main() {
  test('reorderTaskIds moves the dragged item using Reorderable semantics', () {
    expect(reorderTaskIds(['a', 'b', 'c'], 0, 2), ['b', 'a', 'c']);
    expect(reorderTaskIds(['a', 'b', 'c'], 2, 0), ['c', 'a', 'b']);
    expect(reorderTaskIds(['a', 'b', 'c'], 1, 1), ['a', 'b', 'c']);
  });
}
