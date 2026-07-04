import 'package:flutter/material.dart';

/// M11-B2 颜色 hex 解析辅助（标签 + 任务 chips 复用）。
Color parseHexColor(String? hex) {
  if (hex == null || hex.isEmpty) return Colors.grey;
  final v = hex.replaceFirst('#', '');
  final i = int.tryParse(v, radix: 16);
  if (i == null) return Colors.grey;
  if (v.length == 6) return Color(0xFF000000 | i);
  return Color(i);
}