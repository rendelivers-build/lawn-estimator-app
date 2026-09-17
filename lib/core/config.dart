/// App-wide configuration.
///
/// The Google Maps / Places API key is never hardcoded. It is injected at
/// build time with `--dart-define=MAPS_API_KEY=...` and surfaced here for
/// the Dart-side Places SDK; the Android manifest placeholder gets it from
/// `android/local.properties` (see README).
class AppConfig {
  const AppConfig._();

  static const mapsApiKey = String.fromEnvironment(
    'MAPS_API_KEY',
    defaultValue: '',
  );

  static bool get hasMapsKey => mapsApiKey.isNotEmpty;
}
