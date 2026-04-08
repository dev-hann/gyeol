import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gyeol/core/theme/app_theme.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/providers/app_providers.dart';
import 'package:gyeol/shared/widgets/page_header.dart';
import 'package:gyeol/shared/widgets/empty_state.dart';
import 'package:gyeol/shared/widgets/status_badge.dart';

class WorkersPage extends ConsumerStatefulWidget {
  const WorkersPage({super.key});

  @override
  ConsumerState<WorkersPage> createState() => _WorkersPageState();
}

class _WorkersPageState extends ConsumerState<WorkersPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final workersAsync = ref.watch(workersProvider);
    final layersAsync = ref.watch(layersProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PageHeader(
              icon: Icons.memory,
              title: 'Workers',
              description: 'Overview of all workers across layers',
            ),
            const SizedBox(height: 20),
            _buildInfoBanner(),
            const SizedBox(height: 16),
            Expanded(
              child: workersAsync.when(
                data: (workers) {
                  if (workers.isEmpty) {
                    return const EmptyState(
                      icon: Icons.memory,
                      title: 'No workers yet',
                      description: 'Add workers through layer configuration',
                    );
                  }
                  return layersAsync.when(
                    data: (layers) => _buildWorkerGroups(layers, workers),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Card(
      color: AppColors.tertiary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(
          color: AppColors.border,
          style: BorderStyle.solid,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline,
              size: 16,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Worker configuration is managed through layers. Go to Layers to add or edit workers.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkerGroups(
    List<LayerDefinition> layers,
    List<WorkerDefinition> workers,
  ) {
    final groups = layers.map((layer) {
      return MapEntry(
        layer,
        workers.where((w) => w.layerName == layer.name).toList(),
      );
    }).toList();

    final unassigned = workers
        .where((w) => !layers.any((l) => l.name == w.layerName))
        .toList();

    return ListView(
      children: [
        ...groups.map((entry) {
          final layer = entry.key;
          final layerWorkers = entry.value;
          return _buildLayerGroup(layer, layerWorkers);
        }),
        if (unassigned.isNotEmpty) _buildUnassignedGroup(unassigned),
      ],
    );
  }

  Widget _buildLayerGroup(
    LayerDefinition layer,
    List<WorkerDefinition> layerWorkers,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: layer.enabled
                      ? AppColors.success
                      : AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                layer.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.foreground,
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(
                status:
                    '${layerWorkers.length} worker${layerWorkers.length != 1 ? 's' : ''}',
              ),
            ],
          ),
          if (layerWorkers.isEmpty)
            const Padding(
              padding: EdgeInsets.only(left: 16, top: 8),
              child: Text(
                'No workers',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            )
          else
            ...layerWorkers.map((w) => _WorkerCard(worker: w)),
        ],
      ),
    );
  }

  Widget _buildUnassignedGroup(List<WorkerDefinition> unassigned) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Unassigned',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(status: '${unassigned.length}'),
            ],
          ),
          ...unassigned.map((w) => _WorkerCard(worker: w, unassigned: true)),
        ],
      ),
    );
  }
}

class _WorkerCard extends StatelessWidget {
  final WorkerDefinition worker;
  final bool unassigned;

  const _WorkerCard({required this.worker, this.unassigned = false});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(left: 16, top: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: unassigned
              ? AppColors.warning.withValues(alpha: 0.3)
              : AppColors.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: worker.enabled ? AppColors.success : AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        worker.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.foreground,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (worker.model != null)
                        StatusBadge(status: worker.model!, fontSize: 10),
                      const SizedBox(width: 4),
                      StatusBadge(
                        status: worker.enabled ? 'Active' : 'Disabled',
                        fontSize: 10,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    worker.systemPrompt.length > 120
                        ? '${worker.systemPrompt.substring(0, 120)}...'
                        : worker.systemPrompt,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontFamily: 'monospace',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Text(
              'T:${worker.temperature?.toStringAsFixed(1) ?? "def"} / M:${worker.maxTokens ?? "def"}',
              style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
