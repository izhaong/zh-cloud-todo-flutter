import 'package:flutter/material.dart';

class SyncRecoveryBanner extends StatefulWidget {
  const SyncRecoveryBanner({
    required this.failedCount,
    required this.onRetry,
    super.key,
  });

  final int failedCount;
  final Future<void> Function() onRetry;

  @override
  State<SyncRecoveryBanner> createState() => _SyncRecoveryBannerState();
}

class _SyncRecoveryBannerState extends State<SyncRecoveryBanner> {
  var _retrying = false;

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      await widget.onRetry();
    } finally {
      if (mounted) setState(() => _retrying = false);
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
        child: Row(
          children: [
            Icon(Icons.sync_problem_outlined, color: colors.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${widget.failedCount} 项同步需要处理',
                style: TextStyle(color: colors.onErrorContainer),
              ),
            ),
            Semantics(
              label: '立即重试',
              button: true,
              child: TextButton(
                onPressed: _retrying ? null : _retry,
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
      ),
    );
  }
}
