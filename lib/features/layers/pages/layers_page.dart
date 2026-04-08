import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gyeol/core/theme/app_theme.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/providers/app_providers.dart';
import 'package:gyeol/shared/widgets/page_header.dart';
import 'package:gyeol/shared/widgets/empty_state.dart';

class LayersPage extends ConsumerStatefulWidget {
  const LayersPage({super.key});

  @override
  ConsumerState<LayersPage> createState() => _LayersPageState();
}

class _LayersPageState extends ConsumerState<LayersPage> {
  @override
  void initState() {
    super.initState();
    ref.invalidate(layersProvider);
  }

  @override
  Widget build(BuildContext context) {
    final layersAsync = ref.watch(layersProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              icon: Icons.layers_outlined,
              title: 'Layers',
              description:
                  'Manage processing layers (graph editor coming soon)',
              action: OutlinedButton.icon(
                onPressed: () => _showAddLayerDialog(context),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Layer'),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: layersAsync.when(
                data: (layers) {
                  if (layers.isEmpty) {
                    return const EmptyState(
                      icon: Icons.layers_outlined,
                      title: 'No layers yet',
                      description:
                          'Create your first layer to start building the workflow',
                    );
                  }
                  return ListView.separated(
                    itemCount: layers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        _LayerCard(layer: layers[index]),
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

  void _showAddLayerDialog(BuildContext context) {
    final nameCtl = TextEditingController();
    final inputCtl = TextEditingController();
    final outputCtl = TextEditingController();
    final workerCtl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text(
          'New Layer',
          style: TextStyle(color: AppColors.foreground),
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtl,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Layer name',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: inputCtl,
                decoration: const InputDecoration(
                  labelText: 'Input Types',
                  hintText: 'issue, question',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: outputCtl,
                decoration: const InputDecoration(
                  labelText: 'Output Types',
                  hintText: 'plan, analysis',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: workerCtl,
                decoration: const InputDecoration(
                  labelText: 'Worker Names',
                  hintText: 'analyzer, planner',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtl.text.isEmpty) return;
              final layer = LayerDefinition(
                name: nameCtl.text,
                inputTypes: _splitCSV(inputCtl.text),
                outputTypes: _splitCSV(outputCtl.text),
                workerNames: _splitCSV(workerCtl.text),
              );
              await ref.read(layersProvider.notifier).saveLayer(layer);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  List<String> _splitCSV(String input) {
    return input
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
}

class _LayerCard extends ConsumerWidget {
  final LayerDefinition layer;
  const _LayerCard({required this.layer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: layer.enabled ? AppColors.success : AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    layer.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.foreground,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      ...layer.inputTypes.map(
                        (t) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.info.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            t,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.info,
                            ),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          Icons.arrow_forward,
                          size: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      ...layer.outputTypes.map(
                        (t) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            t,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.success,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (layer.workerNames.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Workers: ${layer.workerNames.join(', ')}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              'Order: ${layer.order}',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                size: 18,
                color: AppColors.error,
              ),
              onPressed: () =>
                  ref.read(layersProvider.notifier).deleteLayer(layer.name),
              tooltip: 'Delete layer',
            ),
          ],
        ),
      ),
    );
  }
}
