import 'package:flutter/material.dart';

import 'focus_immersion_settings.dart';

class FocusImmersivePane extends StatelessWidget {
  const FocusImmersivePane({
    super.key,
    required this.style,
    required this.seconds,
    required this.paused,
    required this.controlsVisible,
    required this.onToggleControls,
    required this.onPauseOrResume,
    required this.onComplete,
    required this.onCancel,
    required this.onExit,
  });

  final FocusTimerStyle style;
  final int seconds;
  final bool paused;
  final bool controlsVisible;
  final VoidCallback onToggleControls;
  final VoidCallback onPauseOrResume;
  final VoidCallback onComplete;
  final VoidCallback onCancel;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final duration = _format(seconds);
    final semanticLabel =
        '沉浸计时：${_semanticDuration(seconds)}，${_styleName(style)}样式';
    return ColoredBox(
      key: const Key('focus-immersive-pane'),
      color: colorScheme.surface,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Semantics(
                      label: semanticLabel,
                      button: true,
                      excludeSemantics: true,
                      child: InkWell(
                        key: const Key('focus-immersive-timer'),
                        borderRadius: BorderRadius.circular(24),
                        onTap: onToggleControls,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 24,
                          ),
                          child: KeyedSubtree(
                            key: Key('focus-immersive-style-${style.name}'),
                            child: _TimerDisplay(
                              style: style,
                              duration: duration,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(paused ? '已暂停' : '专注中'),
                    if (controlsVisible) ...[
                      const SizedBox(height: 28),
                      Semantics(
                        container: true,
                        label: '沉浸专注操作',
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            Tooltip(
                              message: paused ? '恢复专注' : '暂停专注',
                              child: OutlinedButton.icon(
                                onPressed: onPauseOrResume,
                                icon: Icon(
                                  paused ? Icons.play_arrow : Icons.pause,
                                ),
                                label: Text(paused ? '恢复' : '暂停'),
                              ),
                            ),
                            Tooltip(
                              message: '完成专注',
                              child: OutlinedButton.icon(
                                onPressed: onComplete,
                                icon: const Icon(Icons.check),
                                label: const Text('完成'),
                              ),
                            ),
                            Tooltip(
                              message: '取消专注',
                              child: OutlinedButton.icon(
                                onPressed: onCancel,
                                icon: const Icon(Icons.close),
                                label: const Text('取消'),
                              ),
                            ),
                            Tooltip(
                              message: '退出沉浸模式',
                              child: TextButton.icon(
                                onPressed: onExit,
                                icon: const Icon(Icons.close_fullscreen),
                                label: const Text('退出沉浸'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  static String _format(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainder = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainder';
  }

  static String _semanticDuration(int seconds) {
    return '${seconds ~/ 60} 分 ${seconds % 60} 秒';
  }

  static String _styleName(FocusTimerStyle value) {
    return switch (value) {
      FocusTimerStyle.digital => '简约数字',
      FocusTimerStyle.flip => '翻页钟',
      FocusTimerStyle.pixel => '像素时钟',
    };
  }
}

class _TimerDisplay extends StatelessWidget {
  const _TimerDisplay({required this.style, required this.duration});

  final FocusTimerStyle style;
  final String duration;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return switch (style) {
      FocusTimerStyle.digital => Text(duration, style: textTheme.displayLarge),
      FocusTimerStyle.flip => Wrap(
        spacing: 6,
        alignment: WrapAlignment.center,
        children: [
          for (final character in duration.split(''))
            if (character == ':')
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text(':', style: textTheme.displaySmall),
              )
            else
              Container(
                width: 52,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  character,
                  textAlign: TextAlign.center,
                  style: textTheme.displayMedium,
                ),
              ),
        ],
      ),
      FocusTimerStyle.pixel => Text(
        duration,
        style: textTheme.displayLarge?.copyWith(
          fontFamily: 'monospace',
          letterSpacing: 3,
        ),
      ),
    };
  }
}
