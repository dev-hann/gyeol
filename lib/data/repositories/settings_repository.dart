import 'dart:convert';

import 'package:gyeol/data/database/database.dart';
import 'package:gyeol/data/models/provider_models.dart';

class SettingsRepository {
  SettingsRepository(this._db);
  final AppDatabase _db;

  Future<ProviderSettings> getSettings() async {
    final json = await _db.getSettingsJson();
    if (json == null) return const ProviderSettings();
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map<String, dynamic>) {
        return const ProviderSettings();
      }
      return ProviderSettings.fromJson(decoded);
    } on Object {
      return const ProviderSettings();
    }
  }

  Future<void> saveSettings(ProviderSettings settings) {
    return _db.saveSettings(jsonEncode(settings.toJson()));
  }
}
