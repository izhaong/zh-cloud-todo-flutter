import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/error_text.dart';
import '../../core/widgets/app_widgets.dart';

import '../../state/efficiency_providers.dart';
import 'habit_repository.dart';

/// 嘀嗒的图标是可选的（《01-开始坚持一个习惯》:75「填写习惯名称、选择图标」），
/// 这里只放契约 `icon` 列能存的字符串键，不引入新的图标库。
const habitIconChoices = <String, IconData>{
  'water': Icons.water_drop_outlined,
  'run': Icons.directions_run,
  'book': Icons.menu_book_outlined,
  'sleep': Icons.bedtime_outlined,
};

const habitColorChoices = <String>['#22C55E', '#0EA5E9', '#F59E0B', '#EF4444'];

/// 频率档位照抄 `AppTodoHabitBaseVO` 的 `period`：1=每天 2=每周 3=每月。
const habitPeriodChoices = <int, String>{1: '每天', 2: '每周', 3: '每月'};

/// 打卡方式照抄 service 契约 `record_type`（嘀嗒《02-更好地完成习惯.md》：
/// 自动记录每次算一次、手动记录可输入完成量、完成全部当日有记录即完成）。
const habitRecordTypeChoices = <int, String>{1: '自动记录', 2: '手动记录', 3: '完成全部'};

Color habitColor(String? hex, Color fallback) {
  if (hex == null || hex.isEmpty) return fallback;
  final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
  if (value == null) return fallback;
  return Color(value | 0xFF000000);
}

String habitPeriodLabel(int period) =>
    habitPeriodChoices[period] ?? habitPeriodChoices[1]!;

/// 嘀嗒《01-开始坚持一个习惯》:75/:85/:95 与《02-更好地完成习惯》:40：
/// 名称、图标、颜色、频率、目标、提示。返回 true 表示已写入，调用方需刷新。
Future<bool> showHabitEditor(BuildContext context, {HabitDto? habit}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _HabitEditorForm(habit: habit),
  );
  return saved ?? false;
}

class _HabitEditorForm extends ConsumerStatefulWidget {
  const _HabitEditorForm({this.habit});

  final HabitDto? habit;

  @override
  ConsumerState<_HabitEditorForm> createState() => _HabitEditorFormState();
}

class _HabitEditorFormState extends ConsumerState<_HabitEditorForm> {
  late final TextEditingController _name = TextEditingController(
    text: widget.habit?.name ?? '',
  );
  late final TextEditingController _target = TextEditingController(
    text: '${widget.habit?.targetCount ?? 1}',
  );
  late String? _icon = widget.habit?.icon;
  late String? _color = widget.habit?.color;
  late int _period = widget.habit?.period ?? 1;
  late int _recordType = widget.habit?.recordType ?? 1;
  late DateTime? _reminderAt = widget.habit?.reminderAt;

  String? _nameError;
  String? _targetError;
  String? _submitError;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // 在飞守卫：弹层的保存按钮在 await 期间仍可被程序化触发（键盘 Enter、重建后的残留回调），
    // 只靠按钮禁用兜不住 ⇒ 这里再拦一次，漏掉就会重复写同一份表单。
    if (_saving) return;
    final name = _name.text.trim();
    final target = int.tryParse(_target.text.trim()) ?? 0;
    setState(() {
      _nameError = name.isEmpty ? '请填写习惯名称' : null;
      _targetError = name.isNotEmpty && target < 1 ? '目标至少为 1' : null;
      _submitError = null;
    });
    if (_nameError != null || _targetError != null) return;
    setState(() => _saving = true);
    final habit = widget.habit;
    try {
      final repo = ref.read(habitRepositoryProvider);
      if (habit == null) {
        await repo.create(
          name: name,
          icon: _icon,
          color: _color,
          period: _period,
          targetCount: target,
          reminderAt: _reminderAt,
          recordType: _recordType,
        );
      } else {
        await repo.update(
          id: habit.id,
          name: name,
          icon: _icon,
          color: _color,
          period: _period,
          targetCount: target,
          reminderAt: _reminderAt,
          sortOrder: habit.sortOrder,
          recordType: _recordType,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      // 提示必须落在弹层自己的子树里：根 ScaffoldMessenger 会被模态路由盖住。
      setState(() {
        _saving = false;
        _submitError = '保存失败：${describeError(error)}';
      });
    }
  }

  Future<void> _pickReminderTime() async {
    final now = DateTime.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_reminderAt ?? now),
    );
    if (picked == null) return;
    final base = _reminderAt ?? now;
    setState(() {
      _reminderAt = DateTime(
        base.year,
        base.month,
        base.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final habit = widget.habit;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: SingleChildScrollView(
          key: const Key('habit-editor-sheet'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                habit == null ? '新建习惯' : '编辑习惯',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('habit-editor-name'),
                controller: _name,
                maxLength: 64,
                decoration: InputDecoration(
                  labelText: '名称',
                  errorText: _nameError,
                ),
              ),
              const SizedBox(height: 12),
              Text('图标', style: theme.textTheme.labelLarge),
              Wrap(
                spacing: 8,
                children: [
                  for (final entry in habitIconChoices.entries)
                    Semantics(
                      label: '图标 ${entry.key}',
                      button: true,
                      selected: _icon == entry.key,
                      excludeSemantics: true,
                      child: IconButton(
                        key: Key('habit-editor-icon-${entry.key}'),
                        onPressed: () => setState(() => _icon = entry.key),
                        icon: Icon(entry.value),
                        color: _icon == entry.key
                            ? theme.colorScheme.primary
                            : null,
                      ),
                    ),
                ],
              ),
              Text('颜色', style: theme.textTheme.labelLarge),
              Wrap(
                spacing: 8,
                children: [
                  for (final hex in habitColorChoices)
                    Semantics(
                      label: '颜色 $hex',
                      button: true,
                      selected: _color == hex,
                      excludeSemantics: true,
                      child: GestureDetector(
                        key: Key('habit-editor-color-$hex'),
                        onTap: () => setState(() => _color = hex),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: habitColor(hex, theme.colorScheme.primary),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _color == hex
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.outlineVariant,
                              width: _color == hex ? 2 : 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text('频率', style: theme.textTheme.labelLarge),
              Wrap(
                spacing: 8,
                children: [
                  for (final entry in habitPeriodChoices.entries)
                    ChoiceChip(
                      key: Key('habit-editor-period-${entry.key}'),
                      label: Text(entry.value),
                      selected: _period == entry.key,
                      onSelected: (_) => setState(() => _period = entry.key),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              // 嘀嗒把打卡方式放在「编辑-目标-打卡时」路径下；这里拍平到同一张
              // 表单里，三档语义与 service 契约 `record_type` 一一对应。
              Text('打卡方式', style: theme.textTheme.labelLarge),
              Wrap(
                spacing: 8,
                children: [
                  for (final entry in habitRecordTypeChoices.entries)
                    ChoiceChip(
                      key: Key('habit-editor-recordtype-${entry.key}'),
                      label: Text(entry.value),
                      selected: _recordType == entry.key,
                      onSelected: (_) =>
                          setState(() => _recordType = entry.key),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('habit-editor-target'),
                controller: _target,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '目标',
                  errorText: _targetError,
                ),
              ),
              const SizedBox(height: 12),
              // 提示只能设置或改期：契约走 MyBatis-Plus 默认 NOT_NULL 更新策略，
              // 传 null 不会写进 SET 子句 ⇒ 这里不能给一个点了不生效的「不提醒」。
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _reminderAt == null
                          ? '提示：未设置'
                          : '提示：'
                                '${_reminderAt!.hour.toString().padLeft(2, '0')}:'
                                '${_reminderAt!.minute.toString().padLeft(2, '0')}',
                      key: const Key('habit-editor-reminder-label'),
                    ),
                  ),
                  TextButton(
                    key: const Key('habit-editor-reminder'),
                    onPressed: _pickReminderTime,
                    child: const Text('选择时间'),
                  ),
                ],
              ),
              if (_submitError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _submitError!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: AppButton(
                  loading: _saving,
                  onPressed: _save,
                  child: const Text('保存'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
