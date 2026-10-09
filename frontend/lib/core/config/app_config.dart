class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://SERVIDOR:8000/api/v1',
  );

  static const logoAsset = 'assets/images/intema_logo.png';
}
