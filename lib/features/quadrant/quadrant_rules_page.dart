import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/efficiency_api.dart';
import '../../state/efficiency_providers.dart';

/// 四象限规则管理：所有读写均落到 `/app-api/todo/quadrant/**`。
class QuadrantRulesPage extends ConsumerWidget {
  const QuadrantRulesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(quadrantRulesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('四象限规则'),
        actions: [
          IconButton(
            tooltip: '新建规则',
            icon: const Icon(Icons.add),
            onPressed: () => _editRule(context, ref),
          ),
        ],
      ),
      body: rules.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _LoadError(
          error: error,
          onRetry: () => ref.invalidate(quadrantRulesProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return _EmptyRules(onCreate: () => _editRule(context, ref));
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(quadrantRulesProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final rule = items[index];
                return ListTile(
                  leading: Icon(
                    rule.isDefault
                        ? Icons.star
                        : Icons.dashboard_customize_outlined,
                  ),
                  title: Text(rule.name),
                  subtitle: Text(_ruleSummary(rule)),
                  trailing: PopupMenuButton<_RuleAction>(
                    onSelected: (action) {
                      switch (action) {
                        case _RuleAction.edit:
                          _editRule(context, ref, rule: rule);
                        case _RuleAction.delete:
                          _deleteRule(context, ref, rule);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: _RuleAction.edit, child: Text('编辑')),
                      PopupMenuItem(
                        value: _RuleAction.delete,
                        child: Text('删除'),
                      ),
                    ],
                  ),
                  onTap: () => _editRule(context, ref, rule: rule),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editRule(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('新建规则'),
      ),
    );
  }

  static String _ruleSummary(QuadrantRuleDto rule) {
    final suffix = rule.isDefault ? ' · 默认规则' : '';
    if (rule.type != QuadrantRuleType.custom) {
      return '${rule.type.label}$suffix';
    }
    return '${rule.type.label} · ${rule.definitions.length} 个分组$suffix';
  }

  Future<void> _editRule(
    BuildContext context,
    WidgetRef ref, {
    QuadrantRuleDto? rule,
  }) async {
    final draft = await showDialog<_RuleDraft>(
      context: context,
      builder: (_) => _RuleEditorDialog(rule: rule),
    );
    if (draft == null || !context.mounted) return;

    try {
      final api = ref.read(quadrantApiProvider);
      final int savedId;
      if (rule == null) {
        savedId = await api.createRule(
          name: draft.name,
          ruleType: draft.type,
          quadrantsJson: draft.quadrantsJson,
          isDefault: draft.isDefault,
        );
      } else {
        savedId = rule.id;
        await api.updateRule(
          id: rule.id,
          name: draft.name,
          ruleType: draft.type,
          quadrantsJson: draft.quadrantsJson,
          isDefault: draft.isDefault,
        );
      }
      if (draft.isDefault) {
        await _clearOtherDefaults(ref, api, keepId: savedId);
      }
      ref.invalidate(quadrantRulesProvider);
      ref.invalidate(quadrantBoardProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(rule == null ? '规则已创建' : '规则已保存')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('规则保存失败：$error')));
    }
  }

  Future<void> _clearOtherDefaults(
    WidgetRef ref,
    QuadrantApi api, {
    required int keepId,
  }) async {
    final existing = ref.read(quadrantRulesProvider).valueOrNull ?? const [];
    for (final rule in existing) {
      if (rule.id == keepId || !rule.isDefault) continue;
      await api.updateRule(
        id: rule.id,
        name: rule.name,
        ruleType: rule.type,
        quadrantsJson: rule.quadrantsJson,
        isDefault: false,
      );
    }
  }

  Future<void> _deleteRule(
    BuildContext context,
    WidgetRef ref,
    QuadrantRuleDto rule,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除四象限规则'),
        content: Text('确定删除“${rule.name}”吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(quadrantApiProvider).deleteRule(rule.id);
      ref.invalidate(quadrantRulesProvider);
      ref.invalidate(quadrantBoardProvider);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('规则删除失败：$error')));
    }
  }
}

enum _RuleAction { edit, delete }

class _RuleDraft {
  const _RuleDraft({
    required this.name,
    required this.type,
    required this.isDefault,
    this.quadrantsJson,
  });

  final String name;
  final QuadrantRuleType type;
  final bool isDefault;
  final String? quadrantsJson;
}

class _RuleEditorDialog extends StatefulWidget {
  const _RuleEditorDialog({this.rule});

  final QuadrantRuleDto? rule;

  @override
  State<_RuleEditorDialog> createState() => _RuleEditorDialogState();
}

class _RuleEditorDialogState extends State<_RuleEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _customController;
  late QuadrantRuleType _type;
  late bool _isDefault;
  String? _error;

  @override
  void initState() {
    super.initState();
    final rule = widget.rule;
    _nameController = TextEditingController(text: rule?.name ?? '');
    _customController = TextEditingController(
      text:
          rule?.quadrantsJson ??
          '[\n'
              '  {"key": "Q_WORK", "condition": "tag:工作"},\n'
              '  {"key": "Q_FOCUS", "condition": "keyword:周报"}\n'
              ']',
    );
    _type = rule?.type ?? QuadrantRuleType.priorityTime;
    _isDefault = rule?.isDefault ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _customController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '请输入规则名称');
      return;
    }
    String? customJson;
    if (_type == QuadrantRuleType.custom) {
      customJson = _customController.text.trim();
      try {
        final decoded = jsonDecode(customJson);
        if (decoded is! List || decoded.isEmpty) {
          throw const FormatException();
        }
        for (final definition in decoded) {
          if (definition is! Map ||
              definition['key']?.toString().trim().isEmpty != false ||
              definition['condition']?.toString().trim().isEmpty != false) {
            throw const FormatException();
          }
        }
      } on FormatException {
        setState(() => _error = '自定义条件必须是非空的 [{key, condition}] JSON 数组');
        return;
      }
    }
    Navigator.pop(
      context,
      _RuleDraft(
        name: name,
        type: _type,
        quadrantsJson: customJson,
        isDefault: _isDefault,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.rule == null ? '新建四象限规则' : '编辑四象限规则'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                autofocus: true,
                maxLength: 64,
                decoration: const InputDecoration(labelText: '规则名称'),
              ),
              DropdownButtonFormField<QuadrantRuleType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: '分类方式'),
                items: [
                  for (final type in QuadrantRuleType.values)
                    DropdownMenuItem(value: type, child: Text(type.label)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _type = value);
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('设为默认规则'),
                value: _isDefault,
                onChanged: (value) => setState(() => _isDefault = value),
              ),
              if (_type == QuadrantRuleType.custom)
                TextField(
                  controller: _customController,
                  minLines: 5,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    labelText: '自定义分组 JSON',
                    helperText: 'condition 支持 tag:标签名 或 keyword:关键词',
                    alignLabelWithHint: true,
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('保存')),
      ],
    );
  }
}

class _EmptyRules extends StatelessWidget {
  const _EmptyRules({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.dashboard_customize_outlined, size: 48),
          const SizedBox(height: 12),
          const Text('还没有四象限规则'),
          const SizedBox(height: 12),
          FilledButton(onPressed: onCreate, child: const Text('创建第一条规则')),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('规则加载失败：$error'),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}
