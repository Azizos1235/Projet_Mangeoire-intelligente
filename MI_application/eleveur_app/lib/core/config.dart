class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://cloud-server-icjx.onrender.com',
  );

  static String get wsBaseUrl {
    final uri = Uri.parse(apiBaseUrl);
    return switch (uri.scheme) {
      'https' => uri.replace(scheme: 'wss').toString(),
      'http' => uri.replace(scheme: 'ws').toString(),
      _ => throw StateError('API_BASE_URL must use http or https.'),
    };
  }
}
