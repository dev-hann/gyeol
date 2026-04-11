import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gyeol/core/theme/app_theme.dart';
import 'package:gyeol/data/database/database.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/providers/app_providers.dart';
import 'package:gyeol/shared/widgets/page_header.dart';
import 'package:gyeol/shared/widgets/status_badge.dart';
import 'package:intl/intl.dart';

enum LogFilter { all, success, failed }

class MonitoringPage extends ConsumerStatefulWidget {
  const MonitoringPage({super.key});

  @override
  ConsumerState<MonitoringPage> createState() => _MonitoringPageState();
}

class _MonitoringPageState extends ConsumerState<MonitoringPage> {
  LogFilter _logFilter = LogFilter.all;
  String? _expandedTaskId;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      final tasksAsync = ref.read(tasksProvider);
      final hasActive =
          tasksAsync.valueOrNull?.any(
            (t) =>
                t.status == TaskStatus.running ||
                t.status == TaskStatus.pending,
          ) ??
          false;
      if (hasActive) {
        ref
          ..invalidate(tasksProvider)
          ..invalidate(logsProvider);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksProvider);
    final layersAsync = ref.watch(layersProvider);
    final logsAsync = ref.watch(logsProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PageHeader(
              icon: Icons.show_chart,
              title: 'Real-time Monitoring',
              description: 'Live view of task execution and worker activity',
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildActiveTasks(tasksAsync, layersAsync)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildExecutionLogs(logsAsync)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTasks(
    AsyncValue<List<AppTask>> async,
    AsyncValue<List<LayerDefinition>> layersAsync,
  ) {
    final layers = layersAsync.valueOrNull ?? [];
    String layerName(int? id) => id != null
        ? (layers.where((l) => l.id == id).firstOrNull?.name ?? 'N/A')
        : 'N/A';
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Active Tasks',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                  ),
                ),
                async.when(
                  data: (tasks) {
                    final running = tasks
                        .where((t) => t.status == TaskStatus.running)
                        .length;
                    return Text(
                      '$running running',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: async.when(
              data: (tasks) {
                final active = tasks
                    .where(
                      (t) =>
                          t.status == TaskStatus.running ||
                          t.status == TaskStatus.pending,
                    )
                    .toList();
                if (active.isEmpty) {
                  return const Center(
                    child: Text(
                      'No active tasks',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: active.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final task = active[index];
                    final isExpanded = _expandedTaskId == task.id;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _expandedTaskId = isExpanded ? null : task.id;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (task.status == TaskStatus.running)
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.info,
                                    ),
                                  )
                                else
                                  const Icon(
                                    Icons.schedule,
                                    size: 14,
                                    color: AppColors.warning,
                                  ),
                                const SizedBox(width: 8),
                                Text(
                                  task.taskType,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.foreground,
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  isExpanded
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  size: 16,
                                  color: AppColors.textMuted,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${layerName(task.layerId)} / ${task.workerName ?? "unassigned"} | Depth: ${task.depth} | Retry: ${task.retryCount}/${task.maxRetries}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                fontFamily: 'monospace',
                              ),
                            ),
                            if (isExpanded) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.tertiary,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Task ID: ${task.id}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textSecondary,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Layer: ${layerName(task.layerId)}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Retry: ${task.retryCount}/${task.maxRetries}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Builder(
                                      builder: (_) {
                                        final created = DateFormat.Hms().format(
                                          DateTime.fromMillisecondsSinceEpoch(
                                            task.createdAt,
                                          ),
                                        );
                                        return Text(
                                          'Created: $created',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: AppColors.textSecondary,
                                          ),
                                        );
                                      },
                                    ),
                                    if (task.payload != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Payload: ${task.payload}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.textMuted,
                                          fontFamily: 'monospace',
                                        ),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExecutionLogs(AsyncValue<List<ExecutionLog>> async) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Execution Logs',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.foreground,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: LogFilter.values.map((filter) {
                final selected = _logFilter == filter;
                final label = switch (filter) {
                  LogFilter.all => 'All',
                  LogFilter.success => 'Success',
                  LogFilter.failed => 'Failed',
                };
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: selected,
                    onSelected: (_) {
                      setState(() {
                        _logFilter = filter;
                      });
                    },
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    backgroundColor: AppColors.tertiary,
                    labelStyle: TextStyle(
                      fontSize: 11,
                      color: selected
                          ? AppColors.primaryBright
                          : AppColors.textSecondary,
                    ),
                    side: BorderSide(
                      color: selected ? AppColors.primary : AppColors.border,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          Expanded(
            child: async.when(
              data: (logs) {
                final filtered = logs.where((log) {
                  return switch (_logFilter) {
                    LogFilter.all => true,
                    LogFilter.success => log.status == 'success',
                    LogFilter.failed => log.status == 'error',
                  };
                }).toList();
                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      'No logs yet',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final log = filtered[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                log.status == 'success'
                                    ? Icons.check_circle
                                    : Icons.cancel,
                                size: 14,
                                color: log.status == 'success'
                                    ? AppColors.success
                                    : AppColors.error,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                log.workerName ?? 'System',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.foreground,
                                ),
                              ),
                              const SizedBox(width: 8),
                              StatusBadge(status: log.status),
                            ],
                          ),
                          if (log.message != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              log.message!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                fontFamily: 'monospace',
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 2),
                          Text(
                            DateFormat.Hms().format(
                              DateTime.fromMillisecondsSinceEpoch(
                                log.createdAt,
                              ),
                            ),
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}
