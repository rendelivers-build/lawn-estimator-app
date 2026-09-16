# Lawn Estimator

Android-only Flutter app for on-site lawn care estimating. The estimator
searches an address (Google Places), draws lawn polygons on satellite
imagery (Google Maps), confirms the measured area, then generates material
quantities (fertilizer, seed, etc.) and priced line items. Estimates,
measurements, and pricing are stored on-device with sqflite; estimates can
be exported to PDF.

## Feature overview

- **Address search** — Google Places autocomplete finds the job site; the
  map centers on the selected place.
- **Measurement** — draw one or more lawn zones as polygons on satellite
  imagery; area is computed from the vertices and shown in ft².
- **Confirmation** — review the measured area and a site photo before the
  estimate is marked confirmed.
- **Materials** — per-material calculations (rate per 1,000 ft², package
  size, waste %) producing exact quantities and purchase units.
- **Pricing** — per-service rates with owner prices overriding area
  defaults; line items carry a `rate_source` of `'owner'` or
  `'area_default'`.
- **Summary & PDF** — estimate totals exported to PDF via the `printing`
  plugin.
- **Estimate history** — on-device list of estimates with totals.

## Prerequisites

- Flutter 3.22 or newer (stable channel)
- Android SDK with build tools for API 34
- A Google Cloud project with a **Maps SDK for Android** key and a
  **Places API** key (they can be the same key)

## API key setup

The key is never committed or hardcoded. It is supplied in **two places**,
one for each side of the app:

### (a) Android manifest — `android/local.properties`

```sh
cp android/local.properties.example android/local.properties
# then edit android/local.properties and set your real key:
# MAPS_API_KEY=AIza...
```

`android/app/build.gradle` reads this file and injects the key into the
manifest as `${MAPS_API_KEY}` (`com.google.android.geo.API_KEY`).

### (b) Dart-side Places SDK — `--dart-define`

The Flutter `flutter_google_places_sdk` needs the key at runtime. Pass it
every time you run or build:

```sh
flutter run --dart-define=MAPS_API_KEY=AIza...
flutter build apk --release --dart-define=MAPS_API_KEY=AIza...
```

`lib/core/config.dart` exposes it as `AppConfig.mapsApiKey`; if it is
empty, `AppConfig.hasMapsKey` is false and Places features should degrade
gracefully.

## How to run

```sh
flutter pub get
flutter run --dart-define=MAPS_API_KEY=AIza...
```

## How to build

```sh
flutter build apk --release --dart-define=MAPS_API_KEY=AIza...
```

## Release signing & Play key restrictions

1. Generate a release keystore (keep the `.jks` file out of version
   control — `*.jks` and `*.keystore` are gitignored).
2. Add a `signingConfig` in `android/app/build.gradle` (currently the
   release build type points at the debug config as a placeholder).
3. Get the SHA-1 fingerprints of your debug and release keystores:

   ```sh
   keytool -list -v -keystore <your.keystore> -alias <your-alias>
   ```

   For Google Play releases, also copy the **app signing key certificate**
   SHA-1 from Play Console → Release → Setup → App integrity.
4. In the Google Cloud console, restrict your API key:
   - **Application restriction:** Android apps — add package
     `com.rendelivers.lawnestimator` with each SHA-1 fingerprint.
   - **API restrictions:** Maps SDK for Android, Places API only.

## Project structure

```
lib/
  main.dart                       # entry point, ProviderScope
  app.dart                        # MaterialApp + route table
  theme.dart                      # Material 3 theme (green seed)
  models/models.dart              # shared data models (cross-module contract)
  core/
    config.dart                   # AppConfig (MAPS_API_KEY dart-define)
    units.dart                    # US-unit conversions + formatting helpers
  features/
    estimates/estimates_screen.dart        # '/'
    estimates/estimate_detail_screen.dart   # '/estimate' (argument: estimateId)
    address/address_search_screen.dart      # '/address'
    measure/measure_screen.dart             # '/measure'
    confirm/confirm_screen.dart             # '/confirm'
    materials/materials_screen.dart         # '/materials'
    materials/summary_screen.dart           # '/summary'
    pricing/pricing_settings_screen.dart    # '/pricing'
android/
  app/build.gradle                # namespace, SDK levels, MAPS_API_KEY placeholder
  app/src/main/AndroidManifest.xml
  local.properties.example        # copy to local.properties, add real key
```

## Privacy

All estimate data (measurements, photos, pricing) stays on the device in
the local sqflite database. The only network calls to Google are the ones
needed to show the map and search addresses (Maps SDK for Android,
Places API) — the address you type and map tiles are sent to Google.

## Versions note

Dependency versions were chosen in September 2026 against the then-current
stable releases. Run `flutter pub get` and adjust if pub.dev reports newer
stable versions or version-solve conflicts.
