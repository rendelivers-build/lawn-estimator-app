/// App-level settings: Beginner / Expert mode and first-run tutorial state.
///
/// Persisted in the `app_settings` table via [EstimateRepository]; loads
/// once at startup and keeps memory in sync with the database on writes.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lawn_estimator/data/estimate_repository.dart';
import 'package:lawn_estimator/models/models.dart';

const _kModeKey = 'mode';
const _kTutorialSeenKey = 'tutorial_seen';

/// Notifier for app-level settings.
class AppSettingsNotifier extends StateNotifier<AppSettings> {
  AppSettingsNotifier() : super(const AppSettings()) {
    _loadFuture = load();
  }

  Future<void>? _loadFuture;

  /// Completes once the initial database load has finished. Use before
  /// reading settings on app start to avoid racing the async load.
  Future<void> ensureLoaded() => _loadFuture ??= load();

  /// Loads settings from the database; defaults when nothing is stored.
  Future<void> load() async {
    final repo = EstimateRepository();
    final stored = await repo.loadAppSettings();
    final mode = stored[_kModeKey] ?? AppSettings.modeBeginner;
    final tutorialSeen = stored[_kTutorialSeenKey] == '1';
    state = AppSettings(
      mode: mode == AppSettings.modeExpert
          ? AppSettings.modeExpert
          : AppSettings.modeBeginner,
      tutorialSeen: tutorialSeen,
    );
  }

  /// Switches Beginner / Expert mode and persists it.
  Future<void> setMode(String mode) async {
    final repo = EstimateRepository();
    await repo.saveAppSetting(_kModeKey, mode);
    state = state.copyWith(mode: mode);
  }

  /// Records that the first-run tutorial was seen (or dismissed).
  Future<void> setTutorialSeen(bool seen) async {
    final repo = EstimateRepository();
    await repo.saveAppSetting(_kTutorialSeenKey, seen ? '1' : '0');
    state = state.copyWith(tutorialSeen: seen);
  }
}

/// Provider for [AppSettings].
final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>(
  (ref) => AppSettingsNotifier(),
);
