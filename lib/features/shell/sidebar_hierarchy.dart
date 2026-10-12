/// A node flattened from a parent/child hierarchy for sidebar rendering.
class SidebarHierarchyEntry<T> {
  const SidebarHierarchyEntry({required this.node, required this.depth});

  final T node;
  final int depth;
}

/// Flattens an arbitrary hierarchy in stable input order.
///
/// Orphans are treated as roots. Cycles and malformed parent chains degrade to
/// roots after the valid trees, and every node is emitted at most once.
List<SidebarHierarchyEntry<T>> flattenSidebarHierarchy<T>(
  List<T> nodes, {
  required String Function(T node) idOf,
  required String? Function(T node) parentIdOf,
}) {
  final byId = {for (final node in nodes) idOf(node): node};
  final children = <String, List<T>>{};
  final roots = <T>[];
  for (final node in nodes) {
    final id = idOf(node);
    final parentId = parentIdOf(node);
    if (parentId == null || parentId == id || !byId.containsKey(parentId)) {
      roots.add(node);
    } else {
      children.putIfAbsent(parentId, () => []).add(node);
    }
  }

  final result = <SidebarHierarchyEntry<T>>[];
  final emitted = <String>{};
  final visiting = <String>{};

  void visit(T node, int depth) {
    final id = idOf(node);
    if (emitted.contains(id) || !visiting.add(id)) return;
    emitted.add(id);
    result.add(SidebarHierarchyEntry(node: node, depth: depth));
    for (final child in children[id] ?? <T>[]) {
      visit(child, depth + 1);
    }
    visiting.remove(id);
  }

  for (final root in roots) {
    visit(root, 0);
  }
  for (final node in nodes) {
    if (!emitted.contains(idOf(node))) visit(node, 0);
  }
  return result;
}

/// The folder itself plus every ancestor above it — the client-side half of the
/// same rule the server applies to `folderIds` (zh-cloud-service Issue #344):
/// picking a parent folder means picking its whole subtree, so a list that lives
/// in a child folder must still be reachable from the parent.
///
/// The walk stops at the first unknown id (kept as-is) and `visited` bounds it,
/// so a malformed parent chain degrades to a finite set instead of looping.
Set<String> folderAndAncestors(
  String folderId,
  Map<String, String?> parentOf,
) {
  final chain = <String>{folderId};
  String? current = parentOf[folderId];
  while (current != null && chain.add(current)) {
    current = parentOf[current];
  }
  return chain;
}
