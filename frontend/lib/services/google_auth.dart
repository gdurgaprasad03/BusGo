import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../utils/app_config.dart';

/// Why Google sign-in could not finish. [cancelled] means the user simply closed the Google screen.
class GoogleAuthException implements Exception {
  const GoogleAuthException(this.message, {this.cancelled = false});

  final String message;
  final bool cancelled;

  @override
  String toString() => message;
}

/// Gets a Google ID token from the phone. The app never trusts it by itself: it is sent to the BusGo server,
/// which verifies it with Google before logging anybody in.
class GoogleAuth {
  GoogleAuth._();

  static bool _initialized = false;

  /// Reason Google sign-in cannot be used in THIS build, or null when it can be tried.
  /// (The server may still have it switched off; see ApiService.authConfig.)
  static String? get unavailableReason {
    if (AppConfig.offlineDemo) return 'Not available in the offline demo';
    if (AppConfig.googleWebClientId.isEmpty) return 'Not configured in this build';
    if (kIsWeb) return 'Use the Android app';
    return null;
  }

  /// Opens the Google account chooser and returns the ID token.
  static Future<String> getIdToken() async {
    final reason = unavailableReason;
    if (reason != null) throw GoogleAuthException('Google sign-in is unavailable: $reason.');

    final google = GoogleSignIn.instance;
    try {
      if (!_initialized) {
        // The *web* client id is the "server client id": it makes Google issue an ID token for our server.
        await google.initialize(serverClientId: AppConfig.googleWebClientId);
        _initialized = true;
      }
      if (!google.supportsAuthenticate()) {
        throw const GoogleAuthException('Google sign-in is not supported on this device.');
      }
      final account = await google.authenticate();
      final token = account.authentication.idToken;
      if (token == null || token.isEmpty) {
        throw const GoogleAuthException('Google did not return a sign-in token. Please try again.');
      }
      return token;
    } on GoogleSignInException catch (e) {
      switch (e.code) {
        case GoogleSignInExceptionCode.canceled:
          throw const GoogleAuthException('Google sign-in was cancelled.', cancelled: true);
        case GoogleSignInExceptionCode.clientConfigurationError:
          throw const GoogleAuthException(
              'Google sign-in is misconfigured (check the package name, SHA-1 fingerprint and client id in Google Cloud).');
        case GoogleSignInExceptionCode.interrupted:
          throw const GoogleAuthException('Google sign-in was interrupted. Please try again.');
        default:
          throw const GoogleAuthException('Google sign-in failed. Please try again.');
      }
    }
  }

  /// Forgets the Google account on this device (called on logout so the next person can choose another).
  static Future<void> signOut() async {
    if (!_initialized) return;
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Not signed in with Google, or the plugin is unavailable: nothing to do.
    }
  }
}
