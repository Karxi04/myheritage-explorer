class GeoapifyConfig {
  const GeoapifyConfig._();

  // Easiest setup:
  // Replace PASTE_YOUR_GEOAPIFY_API_KEY_HERE with your free Geoapify key.
  //
  // Alternative:
  // flutter run --dart-define=GEOAPIFY_API_KEY=YOUR_KEY
  static const String apiKey = String.fromEnvironment(
    'GEOAPIFY_API_KEY',
    defaultValue: '3073b769472f40cba7217657e78cdab0',
  );

  // Keep this false to save free-plan credits. The planner will estimate
  // walking time locally. Set it to true only when you want Geoapify's
  // precise walking-route times.
  static const bool useRoutingApi = false;

  static bool get isConfigured {
    final key = apiKey.trim();
    return key.isNotEmpty &&
        key != 'PASTE_YOUR_GEOAPIFY_API_KEY_HERE' &&
        !key.startsWith('PASTE_');
  }
}
