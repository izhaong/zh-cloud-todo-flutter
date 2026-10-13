/// 清单作用域视图偏好的键形状。
///
/// 这类偏好的 `sourceKey` 存的是**本设备生成的清单 UUID**，另一台设备对同一个服务端清单
/// 有自己的 UUID。跨设备必须换成服务端清单编号这一种规范键，否则两台设备各写一行，
/// 服务端里互不相干，"每清单偏好跨端一致"就是空的（FL #619）。
///
/// 三种类型各自的本地形状（照抄三个仓储现在的写法，不改它们的存法）：
/// `task_view` 用 `list:<本地id>`，`TASK_SORT`/`TASK_GROUP` 直接用 `<本地id>`；
/// 收集箱在两类里都是固定字面量，本来就与设备无关，因此不参与归一。
abstract final class ListViewPreferenceScope {
  /// 出站/入站共用的规范键前缀。
  static const canonicalPrefix = 'list-server:';

  /// 与设备无关、不许被归一改写的键。
  static const deviceNeutralKeys = <String>{'inbox', 'list:inbox'};

  static const _prefixByType = <String, String>{
    'task_view': 'list:',
    'TASK_SORT': '',
    'TASK_GROUP': '',
  };

  static bool isListScopedType(String? sourceType) =>
      sourceType != null && _prefixByType.containsKey(sourceType);

  /// 本地键里的清单 id。
  ///
  /// 返回 null 表示这条键不参与归一：类型不认识、键是设备无关的固定字面量，
  /// 或者形状不是该类型的本地键（例如历史遗留的 `tasks_by_list`）——
  /// 这几种一律按原样发送，不能当成"清单还没上服务端"而丢掉。
  static String? localListId(String? sourceType, String? sourceKey) {
    final prefix = sourceType == null ? null : _prefixByType[sourceType];
    if (prefix == null || sourceKey == null) return null;
    if (deviceNeutralKeys.contains(sourceKey)) return null;
    if (!sourceKey.startsWith(prefix)) return null;
    final id = sourceKey.substring(prefix.length);
    return id.isEmpty ? null : id;
  }

  /// 出站用的规范键。
  static String canonicalKey(int listServerId) =>
      '$canonicalPrefix$listServerId';

  /// 规范键是否该类型的可能入站键。
  static bool isCanonicalKey(String? sourceKey) =>
      sourceKey != null && sourceKey.startsWith(canonicalPrefix);

  /// 入站时把规范键换回该类型在本设备的形状。
  static String? localKey(String? sourceType, String localListId) {
    final prefix = sourceType == null ? null : _prefixByType[sourceType];
    if (prefix == null) return null;
    return '$prefix$localListId';
  }

  /// 规范键里的服务端清单编号；形状不对返回 null。
  static int? canonicalServerId(String? sourceKey) {
    if (!isCanonicalKey(sourceKey)) return null;
    return int.tryParse(sourceKey!.substring(canonicalPrefix.length));
  }
}
