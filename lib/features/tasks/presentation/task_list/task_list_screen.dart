import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../data/tasks_repository.dart';
import '../../domain/task.dart';
import '../widgets/task_card.dart';

class TaskListScreen extends ConsumerWidget {
  const TaskListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(taskListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.myTasks),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.push('/tasks/new'),
          ),
        ],
      ),
      body: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            AppStrings.genericError,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        data: (tasks) {
          if (tasks.isEmpty) return const _EmptyState();
          return _TaskListBody(tasks: tasks);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/tasks/new'),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          AppStrings.newTask,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _TaskListBody extends StatelessWidget {
  const _TaskListBody({required this.tasks});

  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final pending = tasks.where((t) => t.status.isPending).toList();
    final overdue = pending.where((t) => t.dueDate.isBefore(now)).toList();
    final today = pending
        .where((t) => t.dueDate.isAfter(now) && t.dueDate.isBefore(todayEnd))
        .toList();
    final upcoming = pending.where((t) => t.dueDate.isAfter(todayEnd)).toList();
    final done = tasks
        .where((t) => t.status.isCompleted || t.status.isMissed)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.md,
        AppSizes.sm,
        AppSizes.md,
        AppSizes.xxl + AppSizes.xl,
      ),
      children: [
        if (overdue.isNotEmpty) ...[
          _SectionHeader(
            label: AppStrings.overdue,
            color: AppColors.penalty,
            count: overdue.length,
          ),
          ...overdue.map((t) => _TaskItem(task: t)),
          const Gap(AppSizes.md),
        ],
        if (today.isNotEmpty) ...[
          _SectionHeader(label: AppStrings.today, count: today.length),
          ...today.map((t) => _TaskItem(task: t)),
          const Gap(AppSizes.md),
        ],
        if (upcoming.isNotEmpty) ...[
          _SectionHeader(label: AppStrings.upcoming, count: upcoming.length),
          ...upcoming.map((t) => _TaskItem(task: t)),
          const Gap(AppSizes.md),
        ],
        if (done.isNotEmpty) ...[
          _SectionHeader(
            label: AppStrings.completed,
            color: AppColors.textSecondary,
            count: done.length,
          ),
          ...done.map((t) => _TaskItem(task: t)),
        ],
      ],
    );
  }
}

class _TaskItem extends StatelessWidget {
  const _TaskItem({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm),
      child: TaskCard(
        task: task,
        onTap: () => context.push('/tasks/${task.id}'),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, this.color, this.count});

  final String label;
  final Color? color;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm, top: AppSizes.xs),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color ?? AppColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          if (count != null) ...[
            const Gap(AppSizes.xs),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (color ?? AppColors.textSecondary).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color ?? AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(AppSizes.radiusXl),
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              size: 40,
              color: AppColors.primary,
            ),
          ),
          const Gap(AppSizes.lg),
          Text('No tasks yet', style: Theme.of(context).textTheme.titleLarge),
          const Gap(AppSizes.sm),
          Text(
            'Tap + to create your first You-Do',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
