import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_flow_chart/flutter_flow_chart.dart';
import 'package:gyeol/core/theme/app_theme.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/providers/app_providers.dart';
import 'package:gyeol/features/layers/graph/graph_utils.dart';
import 'package:gyeol/features/layers/graph/flow_canvas.dart';
import 'package:gyeol/features/layers/graph/node_detail_panel.dart';
import 'package:gyeol/shared/widgets/page_header.dart';
import 'package:gyeol/shared/widgets/empty_state.dart';

class LayersPage extends ConsumerStatefulWidget {
  const LayersPage({super.key});

  @override
  ConsumerState<LayersPage> createState() => _LayersPageState();
}

class _LayersPageState extends ConsumerState<LayersPage> {
  Dashboard<LayerGraphData>? _dashboard;
  String? _selectedLayerName;

  @override
  Widget build(BuildContext context) {
    final layersAsync = ref.watch(layersProvider);
    final tasksAsync = ref.watch(tasksProvider);

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 12),
            child: PageHeader(
              icon: Icons.layers_outlined,
              title: 'Layers',
              description:
                  'Graph editor — click nodes to view details, drag to reposition',
              action: OutlinedButton.icon(
                onPressed: () => _showAddLayerDialog(context),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Layer'),
              ),
            ),
          ),
          Expanded(
            child: layersAsync.when(
              data: (layers) {
                final tasks = tasksAsync.valueOrNull ?? [];
                return _buildGraph(layers, tasks);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGraph(List<LayerDefinition> layers, List<AppTask> tasks) {
    if (layers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 60),
        child: EmptyState(
          icon: Icons.layers_outlined,
          title: 'No layers yet',
          description: 'Create your first layer to start building the workflow',
          action: ElevatedButton.icon(
            onPressed: () => _showAddLayerDialog(context),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Layer'),
          ),
        ),
      );
    }

    _dashboard = buildDashboard(layers, tasks);

    return Row(
      children: [
        Expanded(
          child: FlowCanvas(
            dashboard: _dashboard!,
            onNodeTap: (name) => setState(() => _selectedLayerName = name),
          ),
        ),
        if (_selectedLayerName != null)
          NodeDetailPanel(
            layerName: _selectedLayerName,
            onClose: () => setState(() => _selectedLayerName = null),
          ),
      ],
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
