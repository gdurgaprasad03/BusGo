import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/booking.dart';
import '../models/booking_draft.dart';
import '../models/complaint.dart';
import '../models/place.dart';
import '../models/saved_passenger.dart';
import '../models/seat_layout.dart';
import '../models/trip.dart';
import '../models/user.dart';
import '../utils/app_config.dart';
import '../utils/formatters.dart';
import 'api_exception.dart';
import 'local_backend_client.dart';
import 'session.dart';

/// All HTTP calls to the Spring Boot backend live here, so screens never build URLs or parse JSON.
class ApiService {
  ApiService({http.Client? client, String? baseUrl, Session? sessionOverride})
      : _client = client ?? (AppConfig.offlineDemo ? LocalBackendClient() : http.Client()),
        _baseUrl = baseUrl ?? AppConfig.apiBaseUrl,
        _session = sessionOverride ?? session;

  final http.Client _client;
  final String _baseUrl;
  final Session _session;

  /// Called when the server rejects our token (expired / invalid) so the app can go back to login.
  void Function()? onSessionExpired;

  // ---------- Auth & profile ----------

  Future<User> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    final json = await _send('POST', '/api/auth/register', auth: false, body: {
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'password': password,
    });
    return _startSession(json);
  }

  /// [identifier] is an email address or a 10-digit mobile number.
  Future<User> login({required String identifier, required String password}) async {
    final json = await _send('POST', '/api/auth/login',
        auth: false, body: {'identifier': identifier, 'password': password});
    return _startSession(json);
  }

  Future<User> getProfile() async => User.fromJson(await _send('GET', '/api/users/me') as Map<String, dynamic>);

  Future<User> updateProfile({required String fullName, required String phone}) async {
    final json = await _send('PUT', '/api/users/me', body: {'fullName': fullName, 'phone': phone});
    final user = User.fromJson(json as Map<String, dynamic>);
    await _session.updateUser(user);
    return user;
  }

  /// Which optional features the server supports. Never throws: if the server cannot be reached we return null
  /// (unknown) so the login screen can still be used.
  Future<AuthConfig?> authConfig() async {
    try {
      final json = await _send('GET', '/api/auth/config', auth: false) as Map<String, dynamic>;
      return AuthConfig(
        googleEnabled: (json['googleEnabled'] as bool?) ?? false,
        emailEnabled: (json['emailEnabled'] as bool?) ?? false,
      );
    } on ApiException {
      return null;
    }
  }

  /// True/false when the server answered, null when it could not be reached.
  Future<bool?> googleEnabledOnServer() async => (await authConfig())?.googleEnabled;

  /// Signs in with a Google ID token. The server verifies the token with Google; nothing else is trusted.
  Future<User> googleLogin(String idToken) async =>
      _startSession(await _send('POST', '/api/auth/google', auth: false, body: {'idToken': idToken}));

  // ---------- Places ----------

  /// Autocomplete over ~6,200 places in India. An empty [query] lists the biggest places.
  Future<List<Place>> searchPlaces(String query, {String? state, int limit = 25}) async {
    final json = await _send('GET', '/api/places', auth: false, query: {
      'query': query,
      if (state != null && state.isNotEmpty) 'state': state,
      'limit': '$limit',
    });
    return (json as List<dynamic>).map((p) => Place.fromJson(p as Map<String, dynamic>)).toList();
  }

  Future<List<StateInfo>> states() async {
    final json = await _send('GET', '/api/places/states', auth: false);
    return (json as List<dynamic>).map((s) => StateInfo.fromJson(s as Map<String, dynamic>)).toList();
  }

  // ---------- Trips ----------

  Future<List<Trip>> searchTrips({
    required String source,
    required String destination,
    required DateTime date,
  }) async {
    final json = await _send('GET', '/api/trips/search', auth: false, query: {
      'source': source,
      'destination': destination,
      'date': Fmt.apiDate(date),
    });
    return (json as List<dynamic>).map((t) => Trip.fromJson(t as Map<String, dynamic>)).toList();
  }

  Future<Trip> getTrip(int tripId) async =>
      Trip.fromJson(await _send('GET', '/api/trips/$tripId', auth: false) as Map<String, dynamic>);

  Future<SeatLayout> getSeats(int tripId) async =>
      SeatLayout.fromJson(await _send('GET', '/api/trips/$tripId/seats', auth: false) as Map<String, dynamic>);

  // ---------- Bookings ----------

  Future<Booking> createBooking(BookingDraft draft) async =>
      Booking.fromJson(await _send('POST', '/api/bookings', body: draft.toJson()) as Map<String, dynamic>);

  Future<List<Booking>> myBookings() async {
    final json = await _send('GET', '/api/bookings/my');
    return (json as List<dynamic>).map((b) => Booking.fromJson(b as Map<String, dynamic>)).toList();
  }

  Future<Booking> getBooking(int bookingId) async =>
      Booking.fromJson(await _send('GET', '/api/bookings/$bookingId') as Map<String, dynamic>);

  Future<Booking> cancelBooking(int bookingId) async =>
      Booking.fromJson(await _send('PATCH', '/api/bookings/$bookingId/cancel') as Map<String, dynamic>);

  // ---------- Saved passengers ----------

  Future<List<SavedPassenger>> savedPassengers() async {
    final json = await _send('GET', '/api/users/me/passengers');
    return (json as List<dynamic>).map((p) => SavedPassenger.fromJson(p as Map<String, dynamic>)).toList();
  }

  Future<SavedPassenger> addSavedPassenger({required String name, required int age, required String gender}) async =>
      SavedPassenger.fromJson(await _send('POST', '/api/users/me/passengers',
          body: {'name': name, 'age': age, 'gender': gender}) as Map<String, dynamic>);

  Future<void> deleteSavedPassenger(int id) async {
    await _send('DELETE', '/api/users/me/passengers/$id');
  }

  // ---------- Complaints & password reset ----------

  Future<Complaint> raiseComplaint({String? bookingReference, required String subject, required String message}) async =>
      Complaint.fromJson(await _send('POST', '/api/complaints', body: {
        if (bookingReference != null && bookingReference.isNotEmpty) 'bookingReference': bookingReference,
        'subject': subject,
        'message': message,
      }) as Map<String, dynamic>);

  Future<List<Complaint>> myComplaints() async {
    final json = await _send('GET', '/api/complaints/my');
    return (json as List<dynamic>).map((c) => Complaint.fromJson(c as Map<String, dynamic>)).toList();
  }

  /// Step 1 of "forgot password": the server emails a 6-digit code. The answer is always the same, whether or not
  /// the email is registered. [ForgotPasswordResult.offlineCode] is only ever set by the offline demo build, which
  /// has no way to send email.
  Future<ForgotPasswordResult> forgotPassword(String email) async {
    final json = await _send('POST', '/api/auth/forgot-password', auth: false, body: {'email': email})
        as Map<String, dynamic>;
    return ForgotPasswordResult(json['message'] as String? ?? '', json['offlineCode'] as String?);
  }

  /// Step 2: the code from the email plus the new password.
  Future<void> resetPassword({required String email, required String code, required String newPassword}) async {
    await _send('POST', '/api/auth/reset-password',
        auth: false, body: {'email': email, 'code': code, 'newPassword': newPassword});
  }

  // ---------- Misc ----------

  /// Returns normally if the server answers, throws ApiException otherwise.
  Future<void> checkHealth() async {
    await _send('GET', '/api/health', auth: false);
  }

  // ---------- Internals ----------

  Future<User> _startSession(dynamic json) async {
    final map = json as Map<String, dynamic>;
    final user = User.fromJson(map['user'] as Map<String, dynamic>);
    await _session.signIn(map['token'] as String, user);
    return user;
  }

  /// Sends one request and returns the decoded JSON. Every failure becomes an ApiException.
  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool auth = true,
  }) async {
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: query);
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    if (auth && _session.token != null) headers['Authorization'] = 'Bearer ${_session.token}';

    final http.Response response;
    try {
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      final streamed = await _client.send(request).timeout(AppConfig.requestTimeout);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw const ApiException(
        'The server took too long to respond. Check that the backend is running, then try again.',
        isNetworkError: true,
      );
    } catch (_) {
      throw ApiException(
        'Cannot reach the server at $_baseUrl. Check that the backend is running and the address is correct.',
        isNetworkError: true,
      );
    }

    final text = utf8.decode(response.bodyBytes);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (text.isEmpty) return null;
      try {
        return jsonDecode(text);
      } on FormatException {
        throw const ApiException('The server sent an unexpected response.');
      }
    }

    final error = _parseError(response.statusCode, text);
    if (error.isUnauthorized && auth && _session.isLoggedIn) {
      await _session.signOut();
      onSessionExpired?.call();
    }
    throw error;
  }

  ApiException _parseError(int status, String text) {
    String message = 'Something went wrong (error $status).';
    var fields = <String, String>{};
    try {
      final json = jsonDecode(text);
      if (json is Map<String, dynamic>) {
        message = (json['message'] as String?) ?? message;
        final raw = json['fieldErrors'];
        if (raw is Map) {
          fields = raw.map((k, v) => MapEntry(k.toString(), v.toString()));
          if (fields.isNotEmpty) message = fields.values.first;
        }
      }
    } catch (_) {
      // Body was not JSON; keep the generic message.
    }
    return ApiException(message, statusCode: status, fieldErrors: fields);
  }
}

/// App-wide instance. A variable (not final) so tests can replace it with a fake-HTTP version.
ApiService api = ApiService();

/// Optional server features. [emailEnabled] false means the server cannot send email, so a "forgot password" code
/// would never arrive.
class AuthConfig {
  const AuthConfig({required this.googleEnabled, required this.emailEnabled});

  final bool googleEnabled;
  final bool emailEnabled;
}

class ForgotPasswordResult {
  const ForgotPasswordResult(this.message, this.offlineCode);

  final String message;

  /// Only set by the offline demo build (it cannot send email, so the code is shown on screen instead).
  final String? offlineCode;
}