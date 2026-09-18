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
const _kInfoSeenKey = 'info_seen_ids';
const _kMarkupKey = 'materials_markup';

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
    final infoSeenRaw = stored[_kInfoSeenKey] ?? '';
    final infoSeenIds = infoSeenRaw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet();
    final markup =
        double.tryParse(stored[_kMarkupKey] ?? '') ?? 0;
    state = AppSettings(
      mode: mode == AppSettings.modeExpert
          ? AppSettings.modeExpert
          : AppSettings.modeBeginner,
      tutorialSeen: tutorialSeen,
      infoSeenIds: infoSeenIds,
      materialsMarkup: markup,
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

  /// Records that a service/material explainer was auto-shown, so it only
  /// appears once per service in beginner mode.
  Future<void> markInfoSeen(String serviceId) async {
    if (state.infoSeenIds.contains(serviceId)) return;
    final updated = {...state.infoSeenIds, serviceId};
    final repo = EstimateRepository();
    await repo.saveAppSetting(_kInfoSeenKey, updated.join(','));
    state = state.copyWith(infoSeenIds: updated);
  }

  /// Sets the materials markup percent (expert mode) and persists it.
  /// Clamped to 0–1000 to keep typos from producing absurd prices.
  Future<void> setMaterialsMarkup(double percent) async {
    final clamped = percent.clamp(0, 1000).toDouble();
    final repo = EstimateRepository();
    await repo.saveAppSetting(_kMarkupKey, clamped.toString());
    state = state.copyWith(materialsMarkup: clamped);
  }
}

/// Provider for [AppSettings].
final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>(
  (ref) => AppSettingsNotifier(),
);
