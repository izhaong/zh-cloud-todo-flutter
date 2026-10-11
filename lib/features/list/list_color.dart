import 'package:flutter/material.dart';

/// specs/102 / FL #339：清单「颜色」。
///
/// 嘀嗒《02-用清单管理任务.md》:73 只约束「清单有颜色属性」，
/// 色板具体取值本端裁定（嘀嗒未公开色值）。存储口径 `#RRGGBB`
/// （`todo_list.color` 与服务端同形态字符串，见 service `TodoListDO.color`）。
const kListColorChoices = <String>[
  '#4772FA',
  '#00B8D9',
  '#00C853',
  '#FFAB00',
  '#FF6D00',
  '#F44336',
  '#E91E63',
  '#9C27B0',
  '#673AB7',
  '#607D8B',
];

/// `#RRGGBB`（大小写均可）→ 不透明色；null / 非法串一律回 null，不抛错。
Color? listColorFromHex(String? hex) {
  if (hex == null) return null;
  final value = hex.replaceFirst('#', '');
  if (value.length != 6) return null;
  final parsed = int.tryParse(value, radix: 16);
  if (parsed == null) return null;
  return Color(0xFF000000 | parsed);
}
