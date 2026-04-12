import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gyeol/core/theme/app_theme.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/providers/app_providers.dart';
import 'package:gyeol/features/layers/graph/graph_utils.dart';
import 'package:gyeol/features/settings/pages/settings_page.dart';
import 'package:gyeol/providers/model_fetcher.dart';
import 'package:vyuh_node_flow/vyuh_node_flow.dart';

class NodeDetailPanel extends ConsumerStatefulWidget {
  const NodeDetailPanel({
    required this.layerId,
    required this.onClose,
    required this.controller,
    this.onConnectionRemoved,
    super.key,
  });
  final int? layerId;
  final VoidCallback onClose;
  final NodeFlowController<LayerGraphData, void> controller;
  final void Function(String src, String dest)? onConnectionRemoved;

  @override
  ConsumerState<NodeDetailPanel> createState() => _NodeDetailPanelState();
}

class _NodeDetailPanelState extends ConsumerState<NodeDetailPanel> {
  bool _editing = false;
  late TextEditingController _inputCtl;
  late TextEditingController _outputCtl;
  late TextEditingController _orderCtl;
  late TextEditingController _layerPromptCtl;
  bool _enabled = true;

  bool _showWorkerForm = false;
  String? _editingWorkerName;
  late TextEditingController _wNameCtl;
  late TextEditingController _wModelCtl;
  late TextEditingController _wTempCtl;
  late TextEditingController _wTokensCtl;
  late TextEditingController _wPromptCtl;
  bool _wEnabled = true;
  ProviderType _wProviderType = ProviderType.openAI;
  List<String> _wModels = [];
  bool _wLoadingModels = false;

  @override
  void initState() {
    super.initState();
    _inputCtl = TextEditingController();
    _outputCtl = TextEditingController();
    _orderCtl = TextEditingController();
    _layerPromptCtl = TextEditingController();
    _wNameCtl = TextEditingController();
    _wModelCtl = TextEditingController();
    _wTempCtl = TextEditingController(text: '0.7');
    _wTokensCtl = TextEditingController(text: '4096');
    _wPromptCtl = TextEditingController();
  }

  @override
  void didUpdateWidget(covariant NodeDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.layerId != widget.layerId) {
      _editing = false;
      _showWorkerForm = false;
      _editingWorkerName = null;
    }
  }

  void _syncControllersFromLayer(LayerDefinition layer) {
    if (_editing) return;
    _inputCtl.text = layer.inputTypes.join(', ');
    _outputCtl.text = layer.outputTypes.join(', ');
    _orderCtl.text = layer.order.toString();
    _layerPromptCtl.text = layer.layerPrompt ?? '';
    _enabled = layer.enabled;
  }

  @override
  void dispose() {
    _inputCtl.dispose();
    _outputCtl.dispose();
    _orderCtl.dispose();
    _layerPromptCtl.dispose();
    _wNameCtl.dispose();
    _wModelCtl.dispose();
    _wTempCtl.dispose();
    _wTokensCtl.dispose();
    _wPromptCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.layerId == null) return const SizedBox.shrink();

    final layersAsync = ref.watch(layersProvider);
    final workersAsync = ref.watch(workersProvider);

    return layersAsync.when(
      data: (layers) {
        final layer = layers.where((l) => l.id == widget.layerId).firstOrNull;
        if (layer == null) return const SizedBox.shrink();

        return workersAsync.when(
          data: (workers) {
            final layerWorkers = workers
                .where((w) => w.layerId == layer.id)
                .toList();
            return _buildPanel(layer, layerWorkers);
          },
          loading: _buildLoading,
          error: (_, __) => _buildLoading(),
        );
      },
      loading: _buildLoading,
      error: (_, __) => _buildLoading(),
    );
  }

  Widget _buildLoading() {
    return Container(
      width: 400,
      color: AppColors.card,
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildPanel(
    LayerDefinition layer,
    List<WorkerDefinition> layerWorkers,
  ) {
    _syncControllersFromLayer(layer);

    return Container(
      width: 400,
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(layer),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!_editing) _buildViewMode(layer) else _buildEditMode(),
                const SizedBox(height: 20),
                _buildConnectionsSection(layer),
                const SizedBox(height: 20),
                _buildWorkerSection(layerWorkers),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(LayerDefinition layer) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
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
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              layer.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.foreground,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: widget.onClose,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildViewMode(LayerDefinition layer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTypeRow('Input Types', layer.inputTypes, AppColors.info),
        const SizedBox(height: 12),
        _buildTypeRow('Output Types', layer.outputTypes, AppColors.success),
        const SizedBox(height: 12),
        if (layer.layerPrompt != null && layer.layerPrompt!.isNotEmpty) ...[
          const Text(
            'Layer Prompt',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.tertiary,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              layer.layerPrompt!,
              style: const TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: AppColors.textSecondary,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            const Text(
              'Enabled',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: (layer.enabled ? AppColors.success : AppColors.textMuted)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                layer.enabled ? 'Active' : 'Disabled',
                style: TextStyle(
                  fontSize: 11,
                  color: layer.enabled
                      ? AppColors.success
                      : AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _editing = true),
                icon: const Icon(Icons.edit, size: 14),
                label: const Text('Edit'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                size: 18,
                color: AppColors.error,
              ),
              onPressed: () {
                ref.read(layersProvider.notifier).deleteLayer(layer.id);
                widget.onClose();
              },
              tooltip: 'Delete layer',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEditMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _inputCtl,
          decoration: const InputDecoration(
            labelText: 'Input Types (comma-separated)',
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _outputCtl,
          decoration: const InputDecoration(
            labelText: 'Output Types (comma-separated)',
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _orderCtl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Order', isDense: true),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _layerPromptCtl,
          decoration: const InputDecoration(
            labelText: 'Layer Prompt',
            hintText: 'Purpose of this layer (optional)',
            isDense: true,
            alignLabelWithHint: true,
          ),
          maxLines: 3,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Switch(
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
            const Text(
              'Enabled',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _editing = false),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: _saveLayer,
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConnectionsSection(LayerDefinition layer) {
    final nodeId = layer.id.toString();
    final nodeConns = widget.controller.getConnectionsForNode(nodeId);
    final outgoing = <Connection<void>>[];
    final incoming = <Connection<void>>[];

    for (final conn in nodeConns) {
      if (conn.sourceNodeId == nodeId) {
        outgoing.add(conn);
      } else {
        incoming.add(conn);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.alt_route,
              size: 14,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              'Connections (${outgoing.length + incoming.length})',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.foreground,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (outgoing.isEmpty && incoming.isEmpty)
          const Text(
            'No connections',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          )
        else ...[
          if (outgoing.isNotEmpty) ...[
            const Text(
              'Outgoing',
              style: TextStyle(fontSize: 10, color: AppColors.textMuted),
            ),
            const SizedBox(height: 4),
            ...outgoing.map((c) => _buildConnectionTile(c, true)),
          ],
          if (incoming.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Text(
              'Incoming',
              style: TextStyle(fontSize: 10, color: AppColors.textMuted),
            ),
            const SizedBox(height: 4),
            ...incoming.map((c) => _buildConnectionTile(c, false)),
          ],
        ],
      ],
    );
  }

  Widget _buildConnectionTile(Connection<void> conn, bool isOutgoing) {
    final layers = ref.read(layersProvider).valueOrNull ?? [];
    final otherNodeId = isOutgoing ? conn.targetNodeId : conn.sourceNodeId;
    final otherId = int.tryParse(otherNodeId);
    final otherLayer = layers.where((l) => l.id == otherId).firstOrNull;
    final displayName = otherLayer?.name ?? otherNodeId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            isOutgoing ? Icons.arrow_forward : Icons.arrow_back,
            size: 12,
            color: isOutgoing ? AppColors.primaryBright : AppColors.infoBright,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              displayName,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 12),
            onPressed: () {
              final srcName = conn.sourceNodeId;
              final destName = conn.targetNodeId;
              widget.controller.removeConnection(conn.id);
              widget.onConnectionRemoved?.call(srcName, destName);
              setState(() {});
            },
            color: AppColors.error,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            padding: EdgeInsets.zero,
            tooltip: 'Disconnect',
          ),
        ],
      ),
    );
  }

  Widget _buildTypeRow(String label, List<String> types, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
        const SizedBox(height: 4),
        if (types.isEmpty)
          const Text(
            'None',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          )
        else
          Wrap(
            spacing: 4,
            runSpacing: 2,
            children: types
                .map(
                  (t) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      t,
                      style: TextStyle(fontSize: 10, color: color),
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  Widget _buildWorkerSection(List<WorkerDefinition> layerWorkers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.memory,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Workers (${layerWorkers.length})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                  ),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: () {
                _editingWorkerName = null;
                _wNameCtl.clear();
                _wModelCtl.clear();
                _wTempCtl.text = '0.7';
                _wTokensCtl.text = '4096';
                _wPromptCtl.clear();
                _wEnabled = true;
                final settings =
                    ref.read(settingsProvider).valueOrNull ??
                    const ProviderSettings();
                _wProviderType = settings.activeProvider;
                setState(() => _showWorkerForm = true);
              },
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_showWorkerForm) _buildWorkerForm(),
        ...layerWorkers.map(_buildWorkerCard),
      ],
    );
  }

  Widget _buildWorkerCard(WorkerDefinition worker) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.all(10),
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
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        worker.name,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.foreground,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (worker.model != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.info.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            worker.model!,
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.info,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    worker.systemPrompt.length > 80
                        ? '${worker.systemPrompt.substring(0, 80)}...'
                        : worker.systemPrompt,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted,
                      fontFamily: 'monospace',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 14),
              onPressed: () {
                _editingWorkerName = worker.name;
                _wNameCtl.text = worker.name;
                _wModelCtl.text = worker.model ?? '';
                _wTempCtl.text = (worker.temperature ?? 0.7).toString();
                _wTokensCtl.text = (worker.maxTokens ?? 4096).toString();
                _wPromptCtl.text = worker.systemPrompt;
                _wEnabled = worker.enabled;
                setState(() => _showWorkerForm = true);
              },
              color: AppColors.textSecondary,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              padding: EdgeInsets.zero,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 14),
              onPressed: () =>
                  ref.read(workersProvider.notifier).deleteWorker(worker.id),
              color: AppColors.error,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkerForm() {
    final settings =
        ref.watch(settingsProvider).valueOrNull ?? const ProviderSettings();
    final configured = PlatformConfig.configured(settings);
    final validType = configured.any((p) => p.providerType == _wProviderType)
        ? _wProviderType
        : configured.isNotEmpty
        ? configured.first.providerType
        : null;
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        color: AppColors.tertiary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _editingWorkerName != null
                ? 'Edit: $_editingWorkerName'
                : 'New Worker',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _wNameCtl,
            decoration: const InputDecoration(labelText: 'Name', isDense: true),
            enabled: _editingWorkerName == null,
          ),
          const SizedBox(height: 8),
          if (configured.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No providers configured. Add one in Settings first.',
                style: TextStyle(fontSize: 11, color: AppColors.error),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<ProviderType>(
                    initialValue: validType,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Provider',
                      isDense: true,
                    ),
                    items: configured
                        .map(
                          (p) => DropdownMenuItem(
                            value: p.providerType,
                            child: Text(
                              p.name,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          _wProviderType = v;
                          _wModels = [];
                          _wModelCtl.clear();
                        });
                        unawaited(_fetchWorkerModels());
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: _buildWorkerModelField()),
              ],
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _wTempCtl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Temperature',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _wTokensCtl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Max Tokens',
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _wPromptCtl,
            decoration: const InputDecoration(
              labelText: 'System Prompt',
              isDense: true,
              alignLabelWithHint: true,
            ),
            maxLines: 4,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          Row(
            children: [
              Switch(
                value: _wEnabled,
                onChanged: (v) => setState(() => _wEnabled = v),
              ),
              const Text(
                'Enabled',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _showWorkerForm = false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveWorker,
                  child: Text(_editingWorkerName != null ? 'Update' : 'Create'),
                ),
              ),
            ],
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

  void _saveLayer() {
    if (widget.layerId == null) return;
    final layers = ref.read(layersProvider).valueOrNull ?? [];
    final existing = layers.where((l) => l.id == widget.layerId).firstOrNull;
    if (existing == null) return;
    final layer = existing.copyWith(
      inputTypes: _splitCSV(_inputCtl.text),
      outputTypes: _splitCSV(_outputCtl.text),
      order: int.tryParse(_orderCtl.text) ?? 0,
      layerPrompt: _layerPromptCtl.text.isEmpty ? null : _layerPromptCtl.text,
      enabled: _enabled,
    );
    ref.read(layersProvider.notifier).saveLayer(layer);
    setState(() => _editing = false);
  }

  void _saveWorker() {
    if (_wNameCtl.text.isEmpty || widget.layerId == null) return;
    final worker = WorkerDefinition(
      id: 0,
      name: _wNameCtl.text,
      layerId: widget.layerId!,
      systemPrompt: _wPromptCtl.text,
      model: _wModelCtl.text.isEmpty ? null : _wModelCtl.text,
      temperature: double.tryParse(_wTempCtl.text) ?? 0.7,
      maxTokens: int.tryParse(_wTokensCtl.text) ?? 4096,
      enabled: _wEnabled,
    );
    ref.read(workersProvider.notifier).saveWorker(worker);
    setState(() {
      _showWorkerForm = false;
      _editingWorkerName = null;
    });
  }

  Future<void> _fetchWorkerModels() async {
    if (_wLoadingModels) return;
    setState(() => _wLoadingModels = true);

    try {
      final settings =
          ref.read(settingsProvider).valueOrNull ?? const ProviderSettings();
      String? apiKey;
      String? baseUrl;
      CustomApiFormat? format;

      final cfg = settings.configs[_wProviderType];
      if (cfg is OpenAIConfig) {
        apiKey = cfg.apiKey;
      } else if (cfg is OllamaConfig) {
        baseUrl = cfg.baseUrl;
      } else if (cfg is CustomConfig) {
        baseUrl = cfg.baseUrl;
        apiKey = cfg.apiKey;
        format = cfg.apiFormat;
      }

      final models = await ModelFetcher.fetchModels(
        provider: _wProviderType,
        apiKey: apiKey,
        baseUrl: baseUrl,
        apiFormat: format,
      );

      if (mounted) {
        setState(() {
          _wModels = models;
          _wLoadingModels = false;
        });
      }
    } on Object {
      if (mounted) setState(() => _wLoadingModels = false);
    }
  }

  Widget _buildWorkerModelField() {
    if (_wLoadingModels) {
      return const TextField(
        enabled: false,
        decoration: InputDecoration(
          labelText: 'Loading...',
          isDense: true,
          prefixIcon: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_wModels.isNotEmpty) {
      return DropdownButtonFormField<String>(
        initialValue: _wModels.contains(_wModelCtl.text)
            ? _wModelCtl.text
            : null,
        decoration: const InputDecoration(
          labelText: 'Model',
          isDense: true,
          prefixIcon: Icon(Icons.model_training, size: 14),
        ),
        items: _wModels
            .map(
              (m) => DropdownMenuItem(
                value: m,
                child: Text(
                  m,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: (v) {
          if (v != null) {
            _wModelCtl.text = v;
          }
        },
      );
    }

    return TextField(
      controller: _wModelCtl,
      decoration: InputDecoration(
        labelText: 'Model',
        isDense: true,
        hintText: PlatformConfig.findByType(_wProviderType).defaultModel,
      ),
    );
  }
}
