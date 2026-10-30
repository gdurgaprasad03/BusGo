import 'package:flutter/foundation.dart';

/// Central place for settings that change between environments.
class AppConfig {
  AppConfig._();

  /// Override at run time, e.g. for a physical phone:
  ///   flutter run --dart-define=API_BASE_URL=http://192.168.1.25:8080
  static const String _override = String.fromEnvironment('API_BASE_URL');

  /// Offline demo build: the app answers every API call itself (see LocalBackendClient), so no backend is needed.
  ///   flutter build apk --dart-define=OFFLINE_DEMO=true
  /// Ignored when API_BASE_URL is given, so a real backend can still be used.
  static const bool _offlineFlag = bool.fromEnvironment('OFFLINE_DEMO');
  static bool get offlineDemo => _offlineFlag && _override.isEmpty;

  /// Default backend address per platform:
  /// - Android emulator: 10.0.2.2 is the emulator's alias for the computer's localhost.
  /// - Web / desktop: localhost works directly.
  static String get apiBaseUrl {
    if (_override.isNotEmpty) return _override;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }

  static const Duration requestTimeout = Duration(seconds: 12);

  /// OAuth *Web* client id from Google Cloud Console (a client id is public; never put a client secret in the app).
  /// Google sign-in stays disabled until it is given:
  ///   flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=1234-abc.apps.googleusercontent.com
  static const String googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  /// How far ahead demo trips exist (today plus the next 13 days).
  static const int searchDaysAhead = 14;

  /// Bounds of the price-range slider on the filters screen (demo fares fall inside this range).
  static const double priceMin = 100;
  static const double priceMax = 3000;
  static const int maxSeatsPerBooking = 6;

  static const List<List<String>> popularRoutes = [
    ['Kurnool', 'Hyderabad'],
    ['Hyderabad', 'Bengaluru'],
    ['Bengaluru', 'Chennai'],
    ['Hyderabad', 'Vijayawada'],
    ['Delhi', 'Jaipur'],
    ['Mumbai', 'Pune'],
  ];

  static const String demoNotice =
      'Demo data: operators, schedules, ratings and prices are samples, not live information.';
}
