// 用户可见文案里不得出现异常原文（Issue #468 的常驻门禁）。
//
// 判据两条：
//   A. 把异常对象插进字符串：`'$e'`、`'${error}'`、`'${s.error}'` —— 未经 describeError 包裹判红。
//   B. `error.toString()` 这类取异常原文的写法（error_text.dart 自身除外）判红。
//
// 这条判据同时被 test/tooling/raw_error_text_gate_test.dart 调用，所以它跑在
// `flutter test` 里，也就是 Jenkinsfile 真正执行的那一步；不依赖 python。
//
// 手工跑：
//   dart run tool/check_raw_error_text.dart [paths...]
//   dart run tool/check_raw_error_text.dart --selftest

import 'dart:io';

class Finding {
  Finding(this.file, this.line, this.reason, this.snippet);

  final String file;
  final int line;
  final String reason;
  final String snippet;

  @override
  String toString() => '$file:$line $reason ｜ $snippet';
}

const String reasonInterp = '异常对象被插进文案，未经 describeError 转换';
const String reasonToString = '取了异常原文 toString()，不得进用户可见文案';

/// 唯一合法持有异常原文的地方就是转换点本身。
const String helperPath = 'lib/core/api/error_text.dart';

final RegExp _interp = RegExp(
  r'\$\{?([A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*)\}?',
);
final RegExp _wrapped = RegExp(r'\bdescribeError\([^()]*\)');
final RegExp _errish = RegExp(r'(^|\.)(e|err|error|exception)$');
final RegExp _toString = RegExp(
  r'\b([A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*)\.toString\(\)',
);

/// 一个源文件里的失项（跳过注释行）。
List<Finding> findingsForSource(String file, String source) {
  final out = <Finding>[];
  final lines = source.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final raw = lines[i];
    final stripped = raw.trim();
    if (stripped.startsWith('//')) continue;
    final residue = raw.replaceAllMapped(_wrapped, (m) => '');
    for (final m in _interp.allMatches(residue)) {
      if (_errish.hasMatch(m.group(1)!)) {
        out.add(Finding(file, i + 1, reasonInterp, stripped));
        break;
      }
    }
    for (final m in _toString.allMatches(residue)) {
      if (_errish.hasMatch(m.group(1)!)) {
        out.add(Finding(file, i + 1, reasonToString, stripped));
        break;
      }
    }
  }
  return out;
}

/// 扫若干路径下的 .dart（跳过生成物 *.g.dart 与转换点自身）。
List<Finding> scanPaths(List<String> roots, {String skipFile = helperPath}) {
  final findings = <Finding>[];
  for (final root in roots) {
    final entity = FileSystemEntity.typeSync(root);
    if (entity == FileSystemEntityType.directory) {
      for (final file in Directory(root).listSync(recursive: true)) {
        if (file is! File) continue;
        if (!file.path.endsWith('.dart')) continue;
        if (file.path.endsWith('.g.dart')) continue;
        if (file.path.replaceAll(r'\', '/') == skipFile) continue;
        findings.addAll(findingsForSource(file.path, file.readAsStringSync()));
      }
    } else if (entity == FileSystemEntityType.file) {
      if (root != skipFile) {
        findings.addAll(findingsForSource(root, File(root).readAsStringSync()));
      }
    } else {
      throw StateError('路径不存在：$root');
    }
  }
  return findings;
}

const String _badInterpSample = """
class _Page {
  String label(Object e) => '加载标签失败: \$e';
}
""";

const String _badToStringSample = """
void _load() {
  _error = error.toString();
}
""";

const String _goodSample = """
class _Page {
  // '加载标签失败: \$e' 这种写法在注释里出现不算失项
  String label(Object e) => '加载标签失败: \${describeError(e)}';
  String other(Object value) => '值: \$value';
}
""";

/// 自证：坏样本必须判红、好样本不得判红。返回 null 表示通过。
String? selftest() {
  final problems = <String>[];
  if (!findingsForSource(
    'bad.dart',
    _badInterpSample,
  ).any((f) => f.reason == reasonInterp)) {
    problems.add('判据 A 没抓到未包裹的 \$e 插值');
  }
  if (!findingsForSource(
    'bad2.dart',
    _badToStringSample,
  ).any((f) => f.reason == reasonToString)) {
    problems.add('判据 B 没抓到 error.toString()');
  }
  final good = findingsForSource('good.dart', _goodSample);
  if (good.isNotEmpty) {
    problems.add('判据把 describeError(e) 或 \$value 误判成失项：$good');
  }
  return problems.isEmpty ? null : problems.join('；');
}

void main(List<String> args) {
  if (args.contains('--selftest')) {
    final problem = selftest();
    if (problem != null) {
      stdout.writeln('SELFTEST FAIL：$problem');
      exit(1);
    }
    stdout.writeln('SELFTEST PASS');
    return;
  }
  final roots = args.where((a) => !a.startsWith('-')).toList();
  final findings = scanPaths(roots.isEmpty ? const ['lib'] : roots);
  for (final f in findings) {
    stdout.writeln('  x $f');
  }
  stdout.writeln('失项 ${findings.length}');
  exit(findings.isEmpty ? 0 : 1);
}
