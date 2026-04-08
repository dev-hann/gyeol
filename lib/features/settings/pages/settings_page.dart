import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gyeol/core/theme/app_theme.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/providers/app_providers.dart';
import 'package:gyeol/shared/widgets/page_header.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late ProviderSettings _form;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              icon: Icons.settings_outlined,
              title: 'Settings',
              description: 'Configure AI provider and system settings',
              action: settingsAsync.when(
                data: (_) => ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save, size: 16),
                  label: const Text('Save Settings'),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: settingsAsync.when(
                data: (settings) {
                  _form = settings;
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSection('AI Provider', [
                          DropdownButtonFormField<ProviderType>(
                            initialValue: _form.provider,
                            decoration: const InputDecoration(
                              labelText: 'Active Provider',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: ProviderType.openAI,
                                child: Text('OpenAI'),
                              ),
                              DropdownMenuItem(
                                value: ProviderType.anthropic,
                                child: Text('Anthropic'),
                              ),
                              DropdownMenuItem(
                                value: ProviderType.ollama,
                                child: Text('Ollama (Local)'),
                              ),
                            ],
                            onChanged: (v) {
                              if (v != null)
                                setState(
                                  () => _form = _form.copyWith(provider: v),
                                );
                            },
                          ),
                        ]),
                        const SizedBox(height: 20),
                        _buildSection('OpenAI', [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  obscureText: true,
                                  decoration: const InputDecoration(
                                    labelText: 'API Key',
                                  ),
                                  controller: TextEditingController(
                                    text: _form.openaiApiKey,
                                  ),
                                  onChanged: (v) =>
                                      _form = _form.copyWith(openaiApiKey: v),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  decoration: const InputDecoration(
                                    labelText: 'Model',
                                  ),
                                  controller: TextEditingController(
                                    text: _form.openaiModel,
                                  ),
                                  onChanged: (v) =>
                                      _form = _form.copyWith(openaiModel: v),
                                ),
                              ),
                            ],
                          ),
                        ]),
                        const SizedBox(height: 20),
                        _buildSection('Anthropic', [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  obscureText: true,
                                  decoration: const InputDecoration(
                                    labelText: 'API Key',
                                  ),
                                  controller: TextEditingController(
                                    text: _form.anthropicApiKey,
                                  ),
                                  onChanged: (v) => _form = _form.copyWith(
                                    anthropicApiKey: v,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  decoration: const InputDecoration(
                                    labelText: 'Model',
                                  ),
                                  controller: TextEditingController(
                                    text: _form.anthropicModel,
                                  ),
                                  onChanged: (v) =>
                                      _form = _form.copyWith(anthropicModel: v),
                                ),
                              ),
                            ],
                          ),
                        ]),
                        const SizedBox(height: 20),
                        _buildSection('Ollama (Local)', [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  decoration: const InputDecoration(
                                    labelText: 'Base URL',
                                  ),
                                  controller: TextEditingController(
                                    text: _form.ollamaBaseUrl,
                                  ),
                                  onChanged: (v) =>
                                      _form = _form.copyWith(ollamaBaseUrl: v),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  decoration: const InputDecoration(
                                    labelText: 'Model',
                                  ),
                                  controller: TextEditingController(
                                    text: _form.ollamaModel,
                                  ),
                                  onChanged: (v) =>
                                      _form = _form.copyWith(ollamaModel: v),
                                ),
                              ),
                            ],
                          ),
                        ]),
                        const SizedBox(height: 20),
                        _buildSection('Defaults', [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'Default Temperature',
                                  ),
                                  controller: TextEditingController(
                                    text: _form.defaultTemperature.toString(),
                                  ),
                                  onChanged: (v) => _form = _form.copyWith(
                                    defaultTemperature:
                                        double.tryParse(v) ?? 0.7,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Default Max Tokens',
                                  ),
                                  controller: TextEditingController(
                                    text: _form.defaultMaxTokens.toString(),
                                  ),
                                  onChanged: (v) => _form = _form.copyWith(
                                    defaultMaxTokens: int.tryParse(v) ?? 4096,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ]),
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

  Widget _buildSection(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  void _save() {
    ref.read(settingsProvider.notifier).save(_form);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings saved'),
        backgroundColor: AppColors.success,
      ),
    );
  }
}
