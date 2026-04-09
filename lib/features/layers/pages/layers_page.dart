import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gyeol/core/theme/app_theme.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/providers/app_providers.dart';
import 'package:gyeol/features/layers/graph/flow_canvas.dart';
import 'package:gyeol/features/layers/graph/graph_utils.dart';
import 'package:gyeol/features/layers/graph/node_detail_panel.dart';
import 'package:gyeol/shared/widgets/empty_state.dart';
import 'package:gyeol/shared/widgets/page_header.dart';
import 'package:vyuh_node_flow/vyuh_node_flow.dart';

class LayersPage extends ConsumerStatefulWidget {
  const LayersPage({super.key});

  @override
  ConsumerState<LayersPage> createState() => _LayersPageState();
}

class _LayersPageState extends ConsumerState<LayersPage> {
  late NodeFlowController<LayerGraphData, void> _controller;
  String? _selectedLayerName;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = NodeFlowController<LayerGraphData, void>(
      config: NodeFlowConfig(showAttribution: false),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _savePositions() {
    final positions = <String, Offset>{};
    for (final id in _controller.nodeIds) {
      final node = _controller.getNode(id);
      if (node != null) {
        positions[id] = node.position.value;
      }
    }
    if (positions.isNotEmpty && mounted) {
      ref.read(graphStateProvider.notifier).savePositions(positions);
    }
  }

  void _saveManualConnections() {
    if (!mounted) return;
    final graphState = ref.read(graphStateProvider).valueOrNull;
    final removedConnections = graphState?.removedConnections ?? {};
    final savedManual = graphState?.manualConnections ?? {};

    final layers = ref.read(layersProvider).valueOrNull ?? [];
    final autoConnections = buildConnections(layers, removedConnections);
    final autoConnSet = <(String, String)>{};
    for (final conn in autoConnections) {
      autoConnSet.add((conn.sourceNodeId, conn.targetNodeId));
    }

    final liveManual = <(String, String)>{};
    for (final conn in _controller.connections) {
      final pair = (conn.sourceNodeId, conn.targetNodeId);
      if (!autoConnSet.contains(pair) && !removedConnections.contains(pair)) {
        liveManual.add(pair);
      }
    }

    final allManual = {...savedManual, ...liveManual};
    ref.read(graphStateProvider.notifier).saveManualConnections(allManual);
  }

  void _syncController() {
    _savePositions();

    final layers = ref.read(layersProvider).valueOrNull ?? [];
    final tasks = ref.read(tasksProvider).valueOrNull ?? [];
    final graphState = ref.read(graphStateProvider).valueOrNull;
    final removedConnections = graphState?.removedConnections ?? {};
    final savedPositions = graphState?.nodePositions ?? {};
    final newNodes = buildNodes(layers, tasks);
    final autoConnections = buildConnections(layers, removedConnections);

    final autoConnSet = <(String, String)>{};
    for (final conn in autoConnections) {
      autoConnSet.add((conn.sourceNodeId, conn.targetNodeId));
    }

    final savedManual = graphState?.manualConnections ?? {};

    final liveManualConnections = <(String, String)>[];
    for (final conn in _controller.connections) {
      final pair = (conn.sourceNodeId, conn.targetNodeId);
      if (!autoConnSet.contains(pair) && !removedConnections.contains(pair)) {
        liveManualConnections.add(pair);
      }
    }

    final allManual = <(String, String)>{
      ...savedManual,
      ...liveManualConnections,
    };

    final manualConnections = <(String, String)>[];
    for (final conn in _controller.connections) {
      final pair = (conn.sourceNodeId, conn.targetNodeId);
      if (!autoConnSet.contains(pair) && !removedConnections.contains(pair)) {
        manualConnections.add(pair);
      }
    }

    final positionMap = <String, Offset>{};
    for (final id in _controller.nodeIds) {
      final node = _controller.getNode(id);
      if (node != null) {
        positionMap[id] = node.position.value;
      }
    }

    _controller.clearGraph();

    for (final node in newNodes) {
      final pos = positionMap[node.id] ?? savedPositions[node.id];
      if (pos != null) {
        node.position.value = pos;
      }
    }

    for (final node in newNodes) {
      _controller.addNode(node);
    }

    for (final conn in autoConnections) {
      _controller.addConnection(conn);
    }

    var idx = autoConnections.length;
    for (final pair in allManual) {
      if (autoConnSet.contains(pair)) continue;
      final srcNode = _controller.getNode(pair.$1);
      final destNode = _controller.getNode(pair.$2);
      if (srcNode != null && destNode != null) {
        _controller.addConnection(
          Connection<void>(
            id: 'conn-manual-${idx++}',
            sourceNodeId: pair.$1,
            sourcePortId: '${pair.$1}-out',
            targetNodeId: pair.$2,
            targetPortId: '${pair.$2}-in',
          ),
        );
      }
    }

    _persistManualConnections(allManual);
  }

  void _persistManualConnections(Set<(String, String)> manualConns) {
    if (!mounted) return;
    ref.read(graphStateProvider.notifier).saveManualConnections(manualConns);
  }

  @override
  Widget build(BuildContext context) {
    final layersAsync = ref.watch(layersProvider);
    final tasksAsync = ref.watch(tasksProvider);
    final graphAsync = ref.watch(graphStateProvider);

    if (!_initialized &&
        layersAsync.hasValue &&
        tasksAsync.hasValue &&
        graphAsync.hasValue) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncController();
      });
    }

    ref
      ..listen(layersProvider, (prev, next) {
        if (_initialized) _syncController();
      })
      ..listen(tasksProvider, (prev, next) {
        if (_initialized) _syncController();
      });

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
                  'Graph editor — click nodes to view details, '
                  'drag to reposition',
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

    return Row(
      children: [
        Expanded(
          child: FlowCanvas(
            controller: _controller,
            onNodeTap: (name) {
              _savePositions();
              setState(() => _selectedLayerName = name);
            },
            onNodeDragEnd: _savePositions,
            onConnectionCreated: _saveManualConnections,
          ),
        ),
        if (_selectedLayerName != null)
          NodeDetailPanel(
            layerName: _selectedLayerName,
            onClose: () => setState(() => _selectedLayerName = null),
            controller: _controller,
            onConnectionRemoved: (src, dest) {
              final current = ref.read(graphStateProvider).valueOrNull;
              final updated = {...?current?.removedConnections, (src, dest)};
              ref
                  .read(graphStateProvider.notifier)
                  .saveRemovedConnections(updated);
            },
          ),
      ],
    );
  }

  void _showAddLayerDialog(BuildContext context) {
    final nameCtl = TextEditingController();
    final inputCtl = TextEditingController();
    final outputCtl = TextEditingController();
    final workerCtl = TextEditingController();

    showDialog<void>(
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
