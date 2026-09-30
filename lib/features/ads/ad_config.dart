/// AdMob configuration.
///
/// Both values are read from --dart-define at build time so real IDs can be
/// swapped in without a code change:
///
///   --dart-define=ADMOB_APP_ID=ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY
///   --dart-define=ADMOB_BANNER_ID=ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY
///   --dart-define=ADMOB_INTERSTITIAL_ID=ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY
///
/// The compiled-in defaults are Google's OFFICIAL TEST IDs
/// (https://developers.google.com/admob/flutter/test-ads). Test ads always
/// render in debug/phone-test builds; real IDs must NEVER be committed —
/// pass them via --dart-define on the release build command line only.
///
/// Brandon's AdMob setup (his hands, one time):
///   1. Create an AdMob account at apps.admob.com (same Google account as
///      the Play developer account), add an Android app for
///      com.rendelivers.lawnestimator, copy the App ID
///      (ca-app-pub-…~…).
///   2. Create a Banner ad unit in that app, copy the ad unit ID
///      (ca-app-pub-…/…).
///   3. Rebuild with the two --dart-define flags above. The AndroidManifest
///      APPLICATION_ID meta-data is wired to ADMOB_APP_ID via
///      manifestPlaceholders in android/app/build.gradle — no manifest
///      edit needed.
///   4. Add the test device(s) as AdMob test devices while developing so
///      test clicks never risk the account.
library;

/// AdMob application ID. Also injected into AndroidManifest.xml as the
/// com.google.android.gms.ads.APPLICATION_ID meta-data via the
/// "admobAppId" manifestPlaceholder (fed from the same --dart-define).
const String admobAppId = String.fromEnvironment(
  'ADMOB_APP_ID',
  // Official Google test app ID (Android). Renders test ads only.
  defaultValue: 'ca-app-pub-3940256099942544~3347511713',
);

/// Banner ad unit ID used by [AdBannerSlot].
const String bannerAdUnitId = String.fromEnvironment(
  'ADMOB_BANNER_ID',
  // Official Google test banner unit. Renders test ads only.
  defaultValue: 'ca-app-pub-3940256099942544/6300978111',
);

/// Interstitial ad unit ID, shown full-screen after each completed
/// estimate on the free tier (Brandon-approved 2026-09-27). The user must
/// physically dismiss it to continue.
///
/// Pass the production ID via --dart-define=ADMOB_INTERSTITIAL_ID=… on
/// the release build. Until then the compiled-in default is Google's
/// OFFICIAL TEST interstitial unit — test ads only, never billable.
const String interstitialAdUnitId = String.fromEnvironment(
  'ADMOB_INTERSTITIAL_ID',
  // Official Google test interstitial unit (Android). Renders test ads only.
  defaultValue: 'ca-app-pub-3940256099942544/1033173712',
);

/// True when the build is still on Google's test IDs (i.e. no real
/// ADMOB_BANNER_ID / ADMOB_INTERSTITIAL_ID was passed via --dart-define).
bool get usingTestAds =>
    bannerAdUnitId == 'ca-app-pub-3940256099942544/6300978111' ||
    interstitialAdUnitId == 'ca-app-pub-3940256099942544/1033173712';
