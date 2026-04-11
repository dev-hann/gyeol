import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gyeol/core/theme/app_theme.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/providers/app_providers.dart';
import 'package:gyeol/shared/widgets/page_header.dart';

class PlatformConfig {
  const PlatformConfig({
    required this.value,
    required this.name,
    required this.icon,
    required this.providerType,
    this.requiresApiKey = true,
    this.requiresBaseUrl = false,
    this.defaultModel = '',
  });

  final String value;
  final String name;
  final IconData icon;
  final ProviderType providerType;
  final bool requiresApiKey;
  final bool requiresBaseUrl;
  final String defaultModel;

  static const all = <PlatformConfig>[
    PlatformConfig(
      value: 'openai',
      name: 'OpenAI',
      icon: Icons.smart_toy_outlined,
      providerType: ProviderType.openAI,
      defaultModel: 'gpt-4o',
    ),
    PlatformConfig(
      value: 'anthropic',
      name: 'Anthropic',
      icon: Icons.psychology_outlined,
      providerType: ProviderType.anthropic,
      defaultModel: 'claude-sonnet-4-20250514',
    ),
    PlatformConfig(
      value: 'ollama',
      name: 'Ollama',
      icon: Icons.computer_outlined,
      providerType: ProviderType.ollama,
      requiresApiKey: false,
      requiresBaseUrl: true,
      defaultModel: 'llama3',
    ),
    PlatformConfig(
      value: 'custom',
      name: 'Custom',
      icon: Icons.api_outlined,
      providerType: ProviderType.custom,
      requiresBaseUrl: true,
    ),
  ];

  static PlatformConfig findByType(ProviderType type) {
    return all.firstWhere((p) => p.providerType == type);
  }

  static List<PlatformConfig> configured(ProviderSettings settings) {
    return all
        .where((p) => settings.isProviderConfigured(p.providerType))
        .toList();
  }

  static String providerName(ProviderType type) => switch (type) {
    ProviderType.openAI => 'OpenAI',
    ProviderType.anthropic => 'Anthropic',
    ProviderType.ollama => 'Ollama (Local)',
    ProviderType.custom => 'Custom Endpoint',
  };
}

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late ProviderSettings _form;
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PageHeader(
              icon: Icons.settings_outlined,
              title: 'Settings',
              description: 'Configure AI provider and system settings',
            ),
            const SizedBox(height: 24),
            Expanded(
              child: settingsAsync.when(
                data: (settings) {
                  if (!_initialized) {
                    _form = settings;
                    _initialized = true;
                  }
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProviderSection(),
                        const SizedBox(height: 24),
                        _buildDefaultsSection(),
                      ],
                    ),
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

  Widget _buildProviderSection() {
    final platform = PlatformConfig.findByType(_form.activeProvider);
    final isConfigured = _form.active.isConfigured;
    final subtitle = _providerSubtitle();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'AI Provider',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () => _showProviderModal(_form.activeProvider),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Provider'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isConfigured
                    ? AppColors.success.withValues(alpha: 0.08)
                    : AppColors.tertiary,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isConfigured ? AppColors.success : AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      platform.icon,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              PlatformConfig.providerName(_form.activeProvider),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.foreground,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (isConfigured)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Connected',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.success,
                                  ),
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.textMuted.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Not configured',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.outlined(
                    onPressed: () => _showProviderModal(_form.activeProvider),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    tooltip: 'Edit',
                  ),
                  const SizedBox(width: 4),
                  IconButton.outlined(
                    onPressed: () => _showProviderModal(_form.activeProvider),
                    icon: const Icon(Icons.swap_horiz, size: 16),
                    tooltip: 'Switch',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _providerSubtitle() {
    final config = _form.active;
    return switch (config) {
      OpenAIConfig(:final apiKey) =>
        'API Key: ${apiKey.isNotEmpty ? "•••••" : "not set"}',
      AnthropicConfig(:final apiKey) =>
        'API Key: ${apiKey.isNotEmpty ? "•••••" : "not set"}',
      OllamaConfig(:final baseUrl) => baseUrl,
      CustomConfig(:final baseUrl) => baseUrl,
    };
  }

  void _showProviderModal(ProviderType initialType) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ProviderConfigDialog(
        initialType: initialType,
        currentSettings: _form,
        onConfirm: (updated) {
          setState(() {
            _form = updated;
            _initialized = true;
          });
          ref.read(settingsProvider.notifier).save(updated);
        },
      ),
    );
  }

  Widget _buildDefaultsSection() {
    return Card(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ExpansionTile(
          initiallyExpanded: false,
          dense: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          leading: const Icon(
            Icons.tune_outlined,
            size: 20,
            color: AppColors.primary,
          ),
          title: const Text(
            'Generation Defaults',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.foreground,
            ),
          ),
          subtitle: const Text(
            'Temperature, tokens, sampling, and timeout',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Temperature',
                      hintText: '0.0 ~ 2.0',
                      isDense: true,
                    ),
                    controller: TextEditingController(
                      text: _form.defaultTemperature.toString(),
                    ),
                    onChanged: (v) {
                      _form = _form.copyWith(
                        defaultTemperature: double.tryParse(v) ?? 0.7,
                      );
                      ref.read(settingsProvider.notifier).save(_form);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Max Tokens',
                      hintText: '1 ~ 128000',
                      isDense: true,
                    ),
                    controller: TextEditingController(
                      text: _form.defaultMaxTokens.toString(),
                    ),
                    onChanged: (v) {
                      _form = _form.copyWith(
                        defaultMaxTokens: int.tryParse(v) ?? 4096,
                      );
                      ref.read(settingsProvider.notifier).save(_form);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Top P',
                      hintText: '0.0 ~ 1.0',
                      isDense: true,
                    ),
                    controller: TextEditingController(
                      text: _form.defaultTopP.toString(),
                    ),
                    onChanged: (v) {
                      _form = _form.copyWith(
                        defaultTopP: double.tryParse(v) ?? 1.0,
                      );
                      ref.read(settingsProvider.notifier).save(_form);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Timeout (ms)',
                      hintText: 'e.g. 60000',
                      isDense: true,
                    ),
                    controller: TextEditingController(
                      text: _form.defaultTimeout.toString(),
                    ),
                    onChanged: (v) {
                      _form = _form.copyWith(
                        defaultTimeout: int.tryParse(v) ?? 60000,
                      );
                      ref.read(settingsProvider.notifier).save(_form);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Frequency Penalty',
                      hintText: '-2.0 ~ 2.0',
                      isDense: true,
                    ),
                    controller: TextEditingController(
                      text: _form.defaultFrequencyPenalty.toString(),
                    ),
                    onChanged: (v) {
                      _form = _form.copyWith(
                        defaultFrequencyPenalty: double.tryParse(v) ?? 0.0,
                      );
                      ref.read(settingsProvider.notifier).save(_form);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Presence Penalty',
                      hintText: '-2.0 ~ 2.0',
                      isDense: true,
                    ),
                    controller: TextEditingController(
                      text: _form.defaultPresencePenalty.toString(),
                    ),
                    onChanged: (v) {
                      _form = _form.copyWith(
                        defaultPresencePenalty: double.tryParse(v) ?? 0.0,
                      );
                      ref.read(settingsProvider.notifier).save(_form);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Stop Sequences',
                hintText: 'Comma-separated, e.g. "\\n", "END"',
                isDense: true,
              ),
              controller: TextEditingController(
                text: _form.defaultStopSequences.join(', '),
              ),
              onChanged: (v) {
                final sequences = v
                    .split(',')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList();
                _form = _form.copyWith(defaultStopSequences: sequences);
                ref.read(settingsProvider.notifier).save(_form);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderConfigDialog extends StatefulWidget {
  const _ProviderConfigDialog({
    required this.initialType,
    required this.currentSettings,
    required this.onConfirm,
  });

  final ProviderType initialType;
  final ProviderSettings currentSettings;
  final void Function(ProviderSettings) onConfirm;

  @override
  State<_ProviderConfigDialog> createState() => _ProviderConfigDialogState();
}

class _ProviderConfigDialogState extends State<_ProviderConfigDialog> {
  late ProviderType _selectedType;
  late final TextEditingController _baseUrlCtrl;
  late final TextEditingController _apiKeyCtrl;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    _baseUrlCtrl = TextEditingController();
    _apiKeyCtrl = TextEditingController();
    _loadFieldsForType(_selectedType);
  }

  @override
  void dispose() {
    _baseUrlCtrl.dispose();
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  void _loadFieldsForType(ProviderType type) {
    final config = widget.currentSettings.configs[type];
    switch (config) {
      case OpenAIConfig(:final apiKey):
        _apiKeyCtrl.text = apiKey;
        _baseUrlCtrl.clear();
      case AnthropicConfig(:final apiKey):
        _apiKeyCtrl.text = apiKey;
        _baseUrlCtrl.clear();
      case OllamaConfig(:final baseUrl):
        _baseUrlCtrl.text = baseUrl.isEmpty
            ? 'http://localhost:11434'
            : baseUrl;
        _apiKeyCtrl.clear();
      case CustomConfig(:final baseUrl, :final apiKey):
        _baseUrlCtrl.text = baseUrl;
        _apiKeyCtrl.text = apiKey;
      case null:
        _baseUrlCtrl.clear();
        _apiKeyCtrl.clear();
    }
  }

  void _onPlatformChanged(ProviderType? type) {
    if (type == null || type == _selectedType) return;
    setState(() {
      _selectedType = type;
      _loadFieldsForType(type);
    });
  }

  bool get _showBaseUrl =>
      _selectedType == ProviderType.ollama ||
      _selectedType == ProviderType.custom;

  bool get _showApiKey => _selectedType != ProviderType.ollama;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      title: const Text(
        'Configure Provider',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<ProviderType>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Platform',
                prefixIcon: Icon(Icons.dns_outlined, size: 18),
              ),
              items: PlatformConfig.all
                  .map(
                    (p) => DropdownMenuItem(
                      value: p.providerType,
                      child: Row(
                        children: [
                          Icon(
                            p.icon,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(p.name),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _onPlatformChanged,
            ),
            const SizedBox(height: 14),
            if (_showBaseUrl) ...[
              TextField(
                controller: _baseUrlCtrl,
                decoration: InputDecoration(
                  labelText: 'Base URL',
                  hintText: _selectedType == ProviderType.ollama
                      ? 'http://localhost:11434'
                      : 'https://api.example.com/v1',
                  prefixIcon: const Icon(Icons.link, size: 18),
                ),
              ),
              const SizedBox(height: 14),
            ],
            if (_showApiKey) ...[
              TextField(
                controller: _apiKeyCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'API Key',
                  hintText: _selectedType == ProviderType.openAI
                      ? 'sk-...'
                      : 'sk-ant-...',
                  prefixIcon: const Icon(Icons.key_outlined, size: 18),
                ),
              ),
              const SizedBox(height: 14),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.check, size: 16),
          label: const Text('Register'),
        ),
      ],
    );
  }

  void _submit() {
    final ProviderConfig newConfig = switch (_selectedType) {
      ProviderType.openAI => OpenAIConfig(
        apiKey: _apiKeyCtrl.text,
        model:
            (widget.currentSettings.configs[ProviderType.openAI]
                    as OpenAIConfig?)
                ?.model ??
            'gpt-4o',
      ),
      ProviderType.anthropic => AnthropicConfig(
        apiKey: _apiKeyCtrl.text,
        model:
            (widget.currentSettings.configs[ProviderType.anthropic]
                    as AnthropicConfig?)
                ?.model ??
            'claude-sonnet-4-20250514',
      ),
      ProviderType.ollama => OllamaConfig(
        baseUrl: _baseUrlCtrl.text.isEmpty
            ? 'http://localhost:11434'
            : _baseUrlCtrl.text,
        model:
            (widget.currentSettings.configs[ProviderType.ollama]
                    as OllamaConfig?)
                ?.model ??
            'llama3',
      ),
      ProviderType.custom => CustomConfig(
        baseUrl: _baseUrlCtrl.text,
        apiKey: _apiKeyCtrl.text,
        model:
            (widget.currentSettings.configs[ProviderType.custom]
                    as CustomConfig?)
                ?.model ??
            '',
      ),
    };

    final updated = widget.currentSettings
        .withConfig(newConfig)
        .copyWith(activeProvider: _selectedType);

    widget.onConfirm(updated);
    Navigator.of(context).pop();
  }
}
