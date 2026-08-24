import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/yd_button.dart';
import '../../../../services/notification_service.dart';
import '../../../auth/data/auth_repository.dart';
import '../../data/tasks_repository.dart';
import '../../domain/task.dart';
import '../../domain/task_status.dart';

class TaskDetailScreen extends ConsumerStatefulWidget {
  const TaskDetailScreen({super.key, required this.taskId});

  final String? taskId;

  bool get isNew => taskId == null;

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _rewardController = TextEditingController();
  final _penaltyController = TextEditingController();

  DateTime _dueDate = DateTime.now().add(const Duration(hours: 24));
  bool _isLoading = false;
  Task? _existingTask;

  @override
  void initState() {
    super.initState();
    if (!widget.isNew) {
      _loadTask();
    }
  }

  Future<void> _loadTask() async {
    final task = await ref
        .read(tasksRepositoryProvider)
        .getTask(widget.taskId!);
    if (task != null && mounted) {
      setState(() {
        _existingTask = task;
        _titleController.text = task.title;
        _descController.text = task.description ?? '';
        _dueDate = task.dueDate;
        if (task.rewardAmount > 0) {
          _rewardController.text = task.rewardAmount.toStringAsFixed(2);
        }
        if (task.penaltyAmount > 0) {
          _penaltyController.text = task.penaltyAmount.toStringAsFixed(2);
        }
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _rewardController.dispose();
    _penaltyController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueDate),
    );
    if (time == null || !mounted) return;

    setState(() {
      _dueDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(tasksRepositoryProvider);
      final userId = ref.read(authStateProvider).valueOrNull?.id ?? '';

      final reward = double.tryParse(_rewardController.text) ?? 0.0;
      final penalty = double.tryParse(_penaltyController.text) ?? 0.0;

      if (widget.isNew) {
        final task = Task.create(
          userId: userId,
          title: _titleController.text.trim(),
          description: _descController.text.trim().isEmpty
              ? null
              : _descController.text.trim(),
          dueDate: _dueDate,
          rewardAmount: reward,
          penaltyAmount: penalty,
        );
        await repo.createTask(task);
        await NotificationService.scheduleTaskReminder(task);
      } else {
        final updated = _existingTask!.copyWith(
          title: _titleController.text.trim(),
          description: _descController.text.trim().isEmpty
              ? null
              : _descController.text.trim(),
          dueDate: _dueDate,
          rewardAmount: reward,
          penaltyAmount: penalty,
        );
        await repo.updateTask(updated);
        await NotificationService.cancelTaskReminder(updated.id);
        await NotificationService.scheduleTaskReminder(updated);
      }

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppStrings.genericError)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete task?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.penalty),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(tasksRepositoryProvider).deleteTask(widget.taskId!);
    await NotificationService.cancelTaskReminder(widget.taskId!);
    if (mounted) context.go('/tasks');
  }

  Future<void> _markComplete() async {
    final isOnTime = _existingTask!.dueDate.isAfter(DateTime.now());
    if (mounted) {
      context.push(
        '/tasks/${widget.taskId}/complete',
        extra: {'task': _existingTask, 'isOnTime': isOnTime},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canComplete =
        _existingTask != null && _existingTask!.status == TaskStatus.pending;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? AppStrings.newTask : AppStrings.editTask),
        actions: [
          if (!widget.isNew)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _delete,
              color: AppColors.penalty,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.md),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: AppStrings.taskTitle,
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLength: 100,
              validator: (v) =>
                  (v?.trim().isEmpty ?? true) ? 'Task title is required' : null,
            ),
            const Gap(AppSizes.md),
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: AppStrings.taskDescription,
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              maxLength: 500,
            ),
            const Gap(AppSizes.md),
            _DateTimePicker(value: _dueDate, onTap: _pickDateTime),
            const Gap(AppSizes.lg),
            _SectionLabel('Financial Stakes'),
            const Gap(AppSizes.sm),
            _CurrencyField(
              controller: _rewardController,
              label: AppStrings.rewardAmount,
              color: AppColors.rewardGreen,
              icon: Icons.trending_up_rounded,
            ),
            const Gap(AppSizes.md),
            _CurrencyField(
              controller: _penaltyController,
              label: AppStrings.penaltyAmount,
              color: AppColors.penaltyRed,
              icon: Icons.trending_down_rounded,
            ),
            const Gap(AppSizes.xl),
            if (canComplete) ...[
              YdButton(
                label: AppStrings.markComplete,
                onPressed: _markComplete,
                icon: const Icon(Icons.check_rounded, color: Colors.white),
              ),
              const Gap(AppSizes.md),
            ],
            YdButton(
              label: widget.isNew ? 'Create Task' : 'Save Changes',
              onPressed: _save,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }
}

class _DateTimePicker extends StatelessWidget {
  const _DateTimePicker({required this.value, required this.onTap});

  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final formatted =
        '${_monthName(value.month)} ${value.day}, ${value.year}  •  ${_time(value)}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_rounded,
              size: 18,
              color: AppColors.primary,
            ),
            const Gap(AppSizes.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.dueDate,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  formatted,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const Spacer(),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textDisabled,
            ),
          ],
        ),
      ),
    );
  }

  String _monthName(int month) => const [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][month];

  String _time(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }
}

class _CurrencyField extends StatelessWidget {
  const _CurrencyField({
    required this.controller,
    required this.label,
    required this.color,
    required this.icon,
  });

  final TextEditingController controller;
  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: color),
        prefixText: '\$  ',
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (v) {
        if (v == null || v.isEmpty) return null;
        final parsed = double.tryParse(v);
        if (parsed == null || parsed < 0) return 'Enter a valid amount';
        return null;
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        letterSpacing: 0.3,
      ),
    );
  }
}
