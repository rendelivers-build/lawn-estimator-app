import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:lawn_estimator/features/ads/ad_config.dart';
import 'package:lawn_estimator/features/billing/billing_service.dart';

/// Owns AdMob lifecycle for the free tier.
///
/// Ads show only when the user is on the free tier (no active Pro
/// subscription/trial). Pro users never initialize ad objects and never see
/// ad slots — [AdBannerSlot] renders nothing for them.
///
/// Two ad surfaces (Brandon-approved 2026-09-27):
///   - Banner: bottom slot on the summary/home screens (existing).
///   - Interstitial: full-screen after EACH completed estimate, which the
///     user must physically dismiss to continue. Shown only at this
///     natural break point — never on app load, never mid-task — per
///     AdMob interstitial policy.
class AdsService extends ChangeNotifier {
  AdsService._();

  static final AdsService instance = AdsService._();

  bool _initialized = false;

  /// Initializes the MobileAds SDK. Safe to call once at startup; cheap
  /// no-op on repeat calls.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await MobileAds.instance.initialize();
  }

  /// Whether an ad slot should attempt to load right now: free tier only.
  bool get adsEnabled => BillingService.instance.state == BillingState.free;

  // ------------------------------------------------------------------
  // Interstitial
  // ------------------------------------------------------------------

  InterstitialAd? _interstitialAd;
  bool _loadingInterstitial = false;

  /// Preloads one interstitial so it's ready when the next estimate
  /// completes. Call once the billing tier is known, and again after
  /// every show (see [showInterstitialIfReady]). Safe no-op for Pro and
  /// while a load is already in flight.
  Future<void> loadInterstitial() async {
    if (!adsEnabled || _loadingInterstitial || _interstitialAd != null) return;
    _loadingInterstitial = true;
    try {
      await InterstitialAd.load(
        adUnitId: interstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) => _interstitialAd = ad,
          onAdFailedToLoad: (_) => _interstitialAd = null,
        ),
      );
    } catch (_) {
      _interstitialAd = null;
    } finally {
      _loadingInterstitial = false;
    }
  }

  void _disposeInterstitial() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
  }

  /// Shows the preloaded interstitial when the user is on the free tier.
  ///
  /// The caller AWAITS this: it completes only after the user physically
  /// dismisses the ad (or immediately when there is no ad ready, or the
  /// user is Pro). A 5-minute watchdog guarantees forward progress even
  /// if the ad callbacks never fire.
  ///
  /// This never triggers a load itself — keep one warm via
  /// [loadInterstitial] (called at startup and after every show).
  Future<void> showInterstitialIfReady() async {
    final ad = _interstitialAd;
    if (!adsEnabled) {
      // Upgraded mid-session: drop any preloaded ad, never show it.
      _disposeInterstitial();
      return;
    }
    if (ad == null) {
      // Nothing ready — warm one up for next time and move on.
      unawaited(loadInterstitial());
      return;
    }
    _interstitialAd = null;
    final dismissed = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        if (!dismissed.isCompleted) dismissed.complete();
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        if (!dismissed.isCompleted) dismissed.complete();
      },
    );
    // Preload the NEXT one now so it's ready after this estimate.
    unawaited(loadInterstitial());
    try {
      await ad.show();
    } catch (_) {
      // Show itself threw: treat as dismissed.
    }
    if (!dismissed.isCompleted) {
      await dismissed.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () {},
      );
    }
  }
}
