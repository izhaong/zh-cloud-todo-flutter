import 'package:flutter/material.dart';

class SystemEntryNote {
  const SystemEntryNote({
    required this.title,
    required this.content,
  });

  final String title;
  final String content;

  SystemEntryNote copyWith({String? title, String? content}) {
    return SystemEntryNote(
      title: title ?? this.title,
      content: content ?? this.content,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'content': content,
  };

  factory SystemEntryNote.fromJson(Map<String, dynamic> json) {
    return SystemEntryNote(
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
    );
  }
}

class SystemEntryImportItem {
  const SystemEntryImportItem({
    required this.source,
    required this.status,
  });

  final String source;
  final String status;

  SystemEntryImportItem copyWith({String? source, String? status}) {
    return SystemEntryImportItem(
      source: source ?? this.source,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
    'source': source,
    'status': status,
  };

  factory SystemEntryImportItem.fromJson(Map<String, dynamic> json) {
    return SystemEntryImportItem(
      source: json['source'] as String? ?? '',
      status: json['status'] as String? ?? '',
    );
  }
}

class SystemEntryTabView extends StatelessWidget {
  const SystemEntryTabView({
    super.key,
    required this.taskCount,
    required this.syncQueueCount,
    required this.notes,
    required this.imports,
    required this.shareStatus,
    required this.onAddNote,
    required this.onSimulateShare,
    required this.onAddImport,
  });

  final int taskCount;
  final int syncQueueCount;
  final List<SystemEntryNote> notes;
  final List<SystemEntryImportItem> imports;
  final String shareStatus;
  final VoidCallback onAddNote;
  final VoidCallback onSimulateShare;
  final VoidCallback onAddImport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('桌面与系统入口', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('小组件、桌面便签、快捷入口、系统分享和导入入口的本地闭环'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const [
            _EntryChip(label: '小组件'),
            _EntryChip(label: '桌面便签'),
            _EntryChip(label: '快捷入口'),
            _EntryChip(label: '系统分享'),
            _EntryChip(label: '导入入口'),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: onSimulateShare,
              icon: const Icon(Icons.ios_share),
              label: const Text('模拟系统分享'),
            ),
            OutlinedButton.icon(
              onPressed: onAddNote,
              icon: const Icon(Icons.note_add_outlined),
              label: const Text('新增桌面便签'),
            ),
            FilledButton.tonalIcon(
              onPressed: onAddImport,
              icon: const Icon(Icons.file_upload_outlined),
              label: const Text('添加导入记录'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _MetricCard(label: '小组件任务', value: '$taskCount'),
            _MetricCard(label: '桌面便签', value: '${notes.length}'),
            _MetricCard(label: '导入记录', value: '${imports.length}'),
            _MetricCard(label: '同步队列', value: '$syncQueueCount'),
          ],
        ),
        const SizedBox(height: 20),
        _Panel(
          title: '小组件数据源',
          icon: Icons.widgets_outlined,
          children: [
            _InfoRow(label: '今日任务', value: '$taskCount 项'),
            _InfoRow(label: '同步状态', value: '$syncQueueCount 条队列'),
            const _InfoRow(label: '入口来源', value: '本地缓存'),
          ],
        ),
        const SizedBox(height: 12),
        _Panel(
          title: '桌面便签',
          icon: Icons.sticky_note_2_outlined,
          children: notes
              .map((note) => _InfoRow(label: note.title, value: note.content))
              .toList(),
        ),
        const SizedBox(height: 12),
        _Panel(
          title: '快捷入口',
          icon: Icons.keyboard_command_key,
          children: const [
            _InfoRow(label: 'N', value: '快速添加'),
            _InfoRow(label: 'C', value: '打开日历'),
            _InfoRow(label: 'E', value: '效率工具'),
            _InfoRow(label: 'S', value: '系统入口'),
          ],
        ),
        const SizedBox(height: 12),
        _Panel(
          title: '系统分享',
          icon: Icons.ios_share,
          children: [_InfoRow(label: '状态', value: shareStatus)],
        ),
        const SizedBox(height: 12),
        _Panel(
          title: '导入入口',
          icon: Icons.file_upload_outlined,
          children: imports
              .map((item) => _InfoRow(label: item.source, value: item.status))
              .toList(),
        ),
      ],
    );
  }
}

class _EntryChip extends StatelessWidget {
  const _EntryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(label));
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 10),
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            if (children.isEmpty)
              const Text('暂无数据')
            else
              ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
