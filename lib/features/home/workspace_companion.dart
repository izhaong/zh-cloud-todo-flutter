import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 嘀嗒《02-功能指南/02-日历/07-任务与日历同时显示.md》里"同时显示"的三个态。
///
/// 方向必须进枚举：`:21`（日历在任务右侧）与 `:31`（任务在日历右侧）是两条不同排布，
/// 只存布尔开关的话，重进工作区就还原不出用户当初是从哪个模块图标开的，两侧主从会翻转。
enum WorkspaceCompanion {
  /// 单模块视图（默认，也是 develop 上的既有形态）。
  off,

  /// 从「任务模块图标」开启：主区是任务清单，日历在右。
  calendarBesideTasks,

  /// 从「日历模块图标」开启：主区是日历，任务清单在右。
  tasksBesideCalendar,
}

/// 源页文案，逐字照抄，不当同义词用。
abstract final class WorkspaceCompanionLabels {
  static const showCalendar = '同时显示日历';
  static const showTasks = '同时显示任务';
  static const close = '关闭同时显示';
}

abstract interface class WorkspaceCompanionStorage {
  Future<String?> readString(String key);

  Future<bool> writeString(String key, String value);
}

class SharedPreferencesWorkspaceCompanionStorage
    implements WorkspaceCompanionStorage {
  const SharedPreferencesWorkspaceCompanionStorage();

  @override
  Future<String?> readString(String key) async {
    return (await SharedPreferences.getInstance()).getString(key);
  }

  @override
  Future<bool> writeString(String key, String value) async {
    return (await SharedPreferences.getInstance()).setString(key, value);
  }
}

class WorkspaceCompanionStore {
  const WorkspaceCompanionStore({required WorkspaceCompanionStorage storage})
    : _storage = storage;

  static const storageKey = 'todo_workspace_companion_v1';

  final WorkspaceCompanionStorage _storage;

  Future<WorkspaceCompanion> read() async {
    try {
      final raw = await _storage.readString(storageKey);
      if (raw == null || raw.isEmpty) return WorkspaceCompanion.off;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return WorkspaceCompanion.off;
      final name = decoded['companion'];
      if (name is! String) return WorkspaceCompanion.off;
      for (final value in WorkspaceCompanion.values) {
        if (value.name == name) return value;
      }
      return WorkspaceCompanion.off;
    } catch (_) {
      return WorkspaceCompanion.off;
    }
  }

  Future<bool> write(WorkspaceCompanion value) async {
    try {
      return await _storage.writeString(
        storageKey,
        jsonEncode({'companion': value.name}),
      );
    } catch (_) {
      return false;
    }
  }
}

/// 界面层的并列状态。
///
/// 读盘失败或还没有值时回落 [WorkspaceCompanion.off]；写盘失败**不回滚界面** ——
/// 用户已经看到的并列不该因为存储拒绝而消失。
class WorkspaceCompanionController extends Notifier<WorkspaceCompanion> {
  @override
  WorkspaceCompanion build() {
    final store = WorkspaceCompanionStore(
      storage: ref.watch(workspaceCompanionStorageProvider),
    );
    var cancelled = false;
    ref.onDispose(() => cancelled = true);
    unawaited(
      store.read().then((value) {
        if (!cancelled) state = value;
      }),
    );
    return WorkspaceCompanion.off;
  }

  /// 落库失败时保持已画出来的界面；返回是否写成功，供调用方留痕。
  Future<bool> apply(WorkspaceCompanion value) async {
    state = value;
    return WorkspaceCompanionStore(
      storage: ref.read(workspaceCompanionStorageProvider),
    ).write(value);
  }
}

final workspaceCompanionStorageProvider = Provider<WorkspaceCompanionStorage>(
  (ref) => const SharedPreferencesWorkspaceCompanionStorage(),
);

final workspaceCompanionProvider =
    NotifierProvider<WorkspaceCompanionController, WorkspaceCompanion>(
      WorkspaceCompanionController.new,
    );
