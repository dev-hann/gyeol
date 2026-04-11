import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gyeol/data/models/app_models.dart';
import 'package:gyeol/data/providers/core_providers.dart';

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, ProviderSettings>(
      SettingsNotifier.new,
    );

class SettingsNotifier extends AsyncNotifier<ProviderSettings> {
  @override
  Future<ProviderSettings> build() async {
    final repo = ref.watch(repositoryProvider);
    return repo.settings.getSettings();
  }

  Future<void> save(ProviderSettings settings) async {
    final repo = ref.read(repositoryProvider);
    await repo.settings.saveSettings(settings);
    state = AsyncData(settings);
  }
}
