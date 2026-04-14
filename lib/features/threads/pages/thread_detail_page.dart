import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gyeol/core/theme/app_theme.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/providers/app_providers.dart';
import 'package:gyeol/data/repositories/app_repository.dart';
import 'package:gyeol/features/layers/graph/flow_canvas.dart';
import 'package:gyeol/features/layers/graph/graph_utils.dart';
import 'package:gyeol/features/layers/graph/node_detail_panel.dart';
import 'package:gyeol/shared/widgets/empty_state.dart';
import 'package:vyuh_node_flow/vyuh_node_flow.dart';

class ThreadDetailPage extends ConsumerStatefulWidget {
  const ThreadDetailPage({
    required this.threadId,
    required this.onBack,
    super.key,
  });

  final int threadId;
  final VoidCallback onBack;

  @override
  ConsumerState<ThreadDetailPage> createState() => _ThreadDetailPageState();
}

class _ThreadDetailPageState extends ConsumerState<ThreadDetailPage> {
  late NodeFlowController<LayerGraphData, void> _controller;
  int? _selectedLayerId;
  bool _initialized = false;
  bool _isSyncing = false;
  bool _needsResync = false;
  bool _viewportInitialized = false;
  int _lastSyncHash = 0;
  Timer? _syncDebounce;
  Timer? _viewportDebounce;

  @override
  void initState() {
    super.initState();
    _controller = NodeFlowController<LayerGraphData, void>(
      config: NodeFlowConfig(showAttribution: false),
    );
  }

  @override
  void dispose() {
    _syncDebounce?.cancel();
    _viewportDebounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _savePositions() {
    if (_isSyncing) return;
    final positions = <String, Offset>{};
    for (final id in _controller.nodeIds) {
      final node = _controller.getNode(id);
      if (node != null) {
        positions[id] = node.position.value;
      }
    }
    if (!mounted) return;
    final notifier = ref.read(graphStateProvider.notifier);
    if (positions.isNotEmpty) {
      notifier.savePositionsSilent(positions);
    }
    _scheduleViewportSave();
  }

  void _scheduleViewportSave() {
    _viewportDebounce?.cancel();
    _viewportDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final pan = _controller.currentPan;
      ref
          .read(graphStateProvider.notifier)
          .saveViewportSilent(pan.dx, pan.dy, _controller.currentZoom);
    });
  }

  Future<void> _arrangeLayout() async {
    _viewportInitialized = false;
    _lastSyncHash = 0;
    await ref.read(graphStateProvider.notifier).clearPositions();
    _controller.clearGraph();
    _syncController();
  }

  void _scheduleSync() {
    if (_isSyncing) {
      _needsResync = true;
      return;
    }
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted && !_isSyncing) _syncController();
    });
  }

  void _autoSyncConnections(
    List<LayerDefinition> layers,
    List<LayerConnectionData> existing,
  ) {
    final existingSet = <(int, int)>{};
    for (final c in existing) {
      existingSet.add((c.sourceLayerId, c.targetLayerId));
    }

    final layerMap = <int, LayerDefinition>{};
    for (final l in layers) {
      layerMap[l.id] = l;
    }

    final notifier = ref.read(connectionsProvider.notifier);
    for (final src in layers) {
      if (src.outputTypes.isEmpty) continue;
      final srcOutputs = src.outputTypes.toSet();
      for (final dst in layers) {
        if (src.id == dst.id) continue;
        if (dst.inputTypes.isEmpty) continue;
        final key = (src.id, dst.id);
        if (existingSet.contains(key)) continue;
        if (srcOutputs.intersection(dst.inputTypes.toSet()).isNotEmpty) {
          notifier.saveConnection(
            LayerConnectionData(sourceLayerId: src.id, targetLayerId: dst.id),
          );
        }
      }
    }
  }

  int _computeDataHash(
    List<LayerDefinition> layers,
    List<LayerConnectionData> connections,
    List<AppTask> tasks,
  ) {
    var hash = 0;
    for (final l in layers) {
      hash = hash ^ l.id.hashCode ^ l.name.hashCode ^ l.enabled.hashCode;
    }
    for (final c in connections) {
      hash = hash ^ c.sourceLayerId.hashCode ^ c.targetLayerId.hashCode;
    }
    return hash ^
        tasks.where((t) => t.status == TaskStatus.running).length.hashCode;
  }

  void _syncController() {
    _isSyncing = true;

    final layers =
        ref.read(threadLayersProvider(widget.threadId)).valueOrNull ?? [];
    final tasks = ref.read(tasksProvider).valueOrNull ?? [];
    final workers = ref.read(workersProvider).valueOrNull ?? [];
    final graphState = ref.read(graphStateProvider).valueOrNull;
    final connections = ref.read(connectionsProvider).valueOrNull ?? [];

    final currentHash = _computeDataHash(layers, connections, tasks);
    if (currentHash == _lastSyncHash && _controller.nodeIds.isNotEmpty) {
      _isSyncing = false;
      return;
    }
    _lastSyncHash = currentHash;

    _autoSyncConnections(layers, connections);

    final updatedConnections = ref.read(connectionsProvider).valueOrNull ?? [];
    final savedPositions = graphState?.nodePositions ?? {};
    final newNodes = buildNodes(layers, tasks, workers, updatedConnections);
    final autoConnections = buildConnections(updatedConnections);

    final positionMap = <String, Offset>{};
    for (final id in _controller.nodeIds) {
      final node = _controller.getNode(id);
      if (node != null) {
        positionMap[id] = node.position.value;
      }
    }

    _controller.clearGraph();

    if (!_viewportInitialized && graphState != null) {
      _controller.setViewport(
        GraphViewport(
          x: graphState.viewportX,
          y: graphState.viewportY,
          zoom: graphState.viewportZoom,
        ),
      );
      _viewportInitialized = true;
    }

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isSyncing = false;
      if (_needsResync) {
        _needsResync = false;
        _scheduleSync();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final layersAsync = ref.watch(threadLayersProvider(widget.threadId));
    final tasksAsync = ref.watch(tasksProvider);
    final graphStateAsync = ref.watch(graphStateProvider);
    final threadsAsync = ref.watch(threadsProvider);

    if (!_initialized &&
        layersAsync.hasValue &&
        tasksAsync.hasValue &&
        graphStateAsync.hasValue) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncController();
      });
    }

    ref
      ..listen(threadLayersProvider(widget.threadId), (prev, next) {
        if (_initialized) _scheduleSync();
      })
      ..listen(tasksProvider, (prev, next) {
        if (_initialized) _scheduleSync();
      })
      ..listen(connectionsProvider, (prev, next) {
        if (_initialized) _scheduleSync();
      });

    final thread = threadsAsync.valueOrNull
        ?.where((t) => t.id == widget.threadId)
        .firstOrNull;

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, thread),
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

  Widget _buildHeader(BuildContext context, ThreadDefinition? thread) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back, size: 20),
            tooltip: 'Back',
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: 12),
          const Icon(
            Icons.account_tree_outlined,
            size: 20,
            color: AppColors.primaryBright,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  thread?.name ?? 'Thread ${widget.threadId}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                  ),
                ),
                if (thread != null)
                  Text(
                    thread.path,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: _arrangeLayout,
            icon: const Icon(Icons.auto_fix_high, size: 18),
            tooltip: 'Auto Arrange',
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => _showAddLayerDialog(context),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Layer'),
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
            onNodeTap: (nodeId) {
              _savePositions();
              setState(() => _selectedLayerId = int.tryParse(nodeId));
            },
            onNodeDragEnd: _savePositions,
            onConnectionCreated: (src, dst) {
              final srcId = int.tryParse(src);
              final dstId = int.tryParse(dst);
              if (srcId != null && dstId != null) {
                ref
                    .read(connectionsProvider.notifier)
                    .saveConnection(
                      LayerConnectionData(
                        sourceLayerId: srcId,
                        targetLayerId: dstId,
                      ),
                    );
              }
            },
            onConnectionRemoved: (src, dst) {
              final srcId = int.tryParse(src);
              final dstId = int.tryParse(dst);
              if (srcId != null && dstId != null) {
                ref
                    .read(connectionsProvider.notifier)
                    .deleteConnection(srcId, dstId);
              }
            },
            onViewportChanged: _savePositions,
          ),
        ),
        if (_selectedLayerId != null)
          NodeDetailPanel(
            layerId: _selectedLayerId,
            onClose: () => setState(() => _selectedLayerId = null),
            controller: _controller,
            onConnectionRemoved: (src, dst) {
              final srcId = int.tryParse(src);
              final dstId = int.tryParse(dst);
              if (srcId != null && dstId != null) {
                ref
                    .read(connectionsProvider.notifier)
                    .deleteConnection(srcId, dstId);
              }
            },
          ),
      ],
    );
  }

  void _showAddLayerDialog(BuildContext context) {
    final nameCtl = TextEditingController();
    final inputCtl = TextEditingController();
    final outputCtl = TextEditingController();

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
                id: 0,
                threadId: widget.threadId,
                name: nameCtl.text,
                inputTypes: _splitCSV(inputCtl.text),
                outputTypes: _splitCSV(outputCtl.text),
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
