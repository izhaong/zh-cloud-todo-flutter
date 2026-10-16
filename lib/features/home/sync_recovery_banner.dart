import 'package:flutter/material.dart';

class SyncRecoveryBanner extends StatefulWidget {
  const SyncRecoveryBanner({
    required this.failedCount,
    this.conflictCount = 0,
    this.recoverableTaskConflictCount = 0,
    required this.onRetry,
    this.onPreserveLocalCopies,
    super.key,
  });

  final int failedCount;
  final int conflictCount;
  final int recoverableTaskConflictCount;
  final Future<void> Function() onRetry;
  final Future<void> Function()? onPreserveLocalCopies;

  @override
  State<SyncRecoveryBanner> createState() => _SyncRecoveryBannerState();
}

class _SyncRecoveryBannerState extends State<SyncRecoveryBanner> {
  var _retrying = false;
  var _preserving = false;

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      await widget.onRetry();
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  Future<void> _preserveLocalCopies() async {
    if (_preserving || _retrying || widget.onPreserveLocalCopies == null) {
      return;
    }
    setState(() => _preserving = true);
    try {
      await widget.onPreserveLocalCopies!();
    } finally {
      if (mounted) setState(() => _preserving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.errorContainer,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.sync_problem_outlined,
                  color: colors.onErrorContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        label: '${widget.failedCount} 项同步需要处理',
                        liveRegion: true,
                        excludeSemantics: true,
                        child: Text(
                          '${widget.failedCount} 项同步需要处理',
                          style: TextStyle(color: colors.onErrorContainer),
                        ),
                      ),
                      if (widget.conflictCount > 0)
                        Semantics(
                          label: '其中 ${widget.conflictCount} 项与其他设备冲突，已采用服务器版本',
                          liveRegion: true,
                          excludeSemantics: true,
                          child: Text(
                            '其中 ${widget.conflictCount} 项与其他设备冲突，已采用服务器版本',
                            style: TextStyle(color: colors.onErrorContainer),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 4,
              children: [
                if (widget.recoverableTaskConflictCount > 0 &&
                    widget.onPreserveLocalCopies != null)
                  Semantics(
                    label: '保留本地副本',
                    button: true,
                    child: TextButton(
                      onPressed: _preserving || _retrying
                          ? null
                          : _preserveLocalCopies,
                      child: _preserving
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('保留本地副本'),
                    ),
                  ),
                Semantics(
                  label: '立即重试',
                  button: true,
                  child: TextButton(
                    onPressed: _retrying || _preserving ? null : _retry,
                    child: _retrying
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('立即重试'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
