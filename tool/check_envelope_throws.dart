// 信封失败必须带业务码出门（Issue #477 的常驻门禁）。
//
// 判据一条：`lib/**` 里把信封里的 msg 直接塞进裸 DioException 的写法
// （`error: <body>['msg']`）判红。这种写法会把 `code` 丢掉，于是
// `describeError` 只能说「网络连接异常」，`ApiClient` 也认不出未登录。
// 信封失败统一走 `envelopeFailure(...)`（唯一合法持有者是 lib/core/api/envelope.dart）。
//
// 与 raw_error_text 门禁同形状：被 test/tooling/envelope_throw_gate_test.dart 调用，
// 所以跑在 `flutter test`（Jenkinsfile 真执行的那一步）里，不依赖 python。
//
// 手工跑：
//   dart run tool/check_envelope_throws.dart [paths...]
//   dart run tool/check_envelope_throws.dart --selftest

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

const String reasonEnvelope =
    '信封失败自己拼了 DioException，业务码被丢掉，必须走 envelopeFailure';

/// 唯一允许直接读信封 msg 的地方。
const String helperPath = 'lib/core/api/envelope.dart';

final RegExp _envelopeMsg = RegExp(r'''error:\s*\w+(\.\w+)*\[['"]msg['"]\]''');

/// 一个源文件里的失项（跳过注释行）。
List<Finding> findingsForSource(String file, String source) {
  final out = <Finding>[];
  final lines = source.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final stripped = lines[i].trim();
    if (stripped.startsWith('//')) continue;
    if (_envelopeMsg.hasMatch(stripped)) {
      out.add(Finding(file, i + 1, reasonEnvelope, stripped));
    }
  }
  return out;
}

/// 扫若干根目录（默认 lib）。返回失项列表。
List<Finding> scanPaths(List<String> roots, {String skipFile = helperPath}) {
  final out = <Finding>[];
  for (final root in roots) {
    final type = FileSystemEntity.typeSync(root);
    if (type == FileSystemEntityType.directory) {
      out.addAll(_scanDir(Directory(root), skipFile));
    } else if (type == FileSystemEntityType.file &&
        root.endsWith('.dart') &&
        root != skipFile) {
      out.addAll(findingsForSource(root, File(root).readAsStringSync()));
    }
  }
  return out;
}

List<Finding> _scanDir(Directory dir, String skipFile) {
  final out = <Finding>[];
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is! File) continue;
    if (!entity.path.endsWith('.dart')) continue;
    if (entity.path.endsWith('.g.dart')) continue;
    if (entity.path == skipFile) continue;
    out.addAll(findingsForSource(entity.path, entity.readAsStringSync()));
  }
  return out;
}

/// 自证门禁会红：坏样本必须判红、好样本不得误判、判据器自身不得恒绿。
String? selftest() {
  const bad = '''
void _unwrap(Map<String, dynamic>? body) {
  throw DioException(
    requestOptions: RequestOptions(path: '/app-api/todo'),
    error: body['msg'] ?? '请求失败',
  );
}
''';
  const good = '''
void _unwrap(Map<String, dynamic>? body) {
  throw envelopeFailure(body!, path: '/app-api/todo');
}
''';
  final hits = findingsForSource('sample_bad.dart', bad);
  if (hits.isEmpty) return '门禁失效：坏样本（信封 msg 直塞 DioException）没判红';
  if (findingsForSource('sample_good.dart', good).isNotEmpty) {
    return '门禁误判：走了 envelopeFailure 的好样本被判红';
  }
  return null;
}

void main(List<String> args) {
  if (args.contains('--selftest')) {
    final failure = selftest();
    if (failure == null) {
      stdout.writeln('selftest OK：坏样本判红、好样本不误判');
      return;
    }
    stderr.writeln(failure);
    exitCode = 1;
    return;
  }
  if (!Directory('lib').existsSync()) {
    stderr.writeln('必须在仓库根跑（找不到 lib/）');
    exitCode = 2;
    return;
  }
  final roots = args.isEmpty ? const ['lib'] : args;
  final findings = scanPaths(roots);
  if (findings.isEmpty) {
    stdout.writeln('信封失败全部走 envelopeFailure，无裸拼。');
    return;
  }
  for (final f in findings) {
    stdout.writeln(f);
  }
  exitCode = 1;
}
