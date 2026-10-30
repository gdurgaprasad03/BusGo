import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// An in-app stand-in for the Spring Boot backend, used by the offline demo build (no server needed).
///
/// It plugs into [ApiService] as its HTTP client, answers the same routes with the same JSON shapes and
/// error format, and applies the same rules as the real backend: demo routes and fares, seat inventory,
/// all-or-nothing booking, 6-seat limit, saved-passenger limits and the demo cancellation policy.
/// Accounts, bookings and complaints are kept on this device only (shared_preferences).
/// Trips are generated from fixed templates for today + 13 days, so they never run out.
class LocalBackendClient extends http.BaseClient {
  LocalBackendClient({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const _storageKey = 'offline_demo_db_v1';
  static const _daysAhead = 14;
  static const _maxSavedPassengers = 10;

  final DateTime Function() _clock;
  Map<String, dynamic>? _db;
  List<_Template> _templates = const [];
  _Catalog? _catalog;
  Future<void> _queue = Future.value(); // handles one request at a time, like a database transaction

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final bodyFuture = request.finalize().bytesToString();
    final result = _queue.then((_) async {
      final body = await bodyFuture;
      await _load();
      await _ensureCatalog();
      final reply = await _handle(request.method, request.url, request.headers, body);
      return reply;
    });
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  // ---------------------------------------------------------------------------------------------
  // Storage
  // ---------------------------------------------------------------------------------------------

  Future<void> _load() async {
    if (_db != null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        _db = jsonDecode(raw) as Map<String, dynamic>;
        return;
      }
    } catch (_) {
      // Fall through to a fresh database.
    }
    _db = {
      'nextId': 1,
      'users': <dynamic>[],
      'bookings': <dynamic>[],
      'passengers': <dynamic>[],
      'complaints': <dynamic>[],
      'soldSeats': <String, dynamic>{}, // tripId -> seat numbers booked by app users
    };
  }

  /// Loads the city catalog and demo routes from the app's data files (the same files the Spring backend uses),
  /// then builds the list of daily bus departures. If the files cannot be read, only the hand-picked core routes exist.
  Future<void> _ensureCatalog() async {
    if (_catalog != null) return;
    Future<List<List<String>>> rows(String name) async {
      try {
        return _parseCsv(await rootBundle.loadString('assets/data/$name'));
      } catch (_) {
        return const [];
      }
    }

    final routes = await rows('demo-routes.csv');
    _catalog = _Catalog(
      cities: await rows('india-cities.csv'),
      aliases: await rows('india-city-aliases.csv'),
      states: await rows('india-states.csv'),
    );
    _templates = _buildTemplates(routes);
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(_db));
    } catch (_) {
      // The in-memory copy still works for this session.
    }
  }

  int _newId() {
    final id = _db!['nextId'] as int;
    _db!['nextId'] = id + 1;
    return id;
  }

  List<Map<String, dynamic>> _list(String key) => (_db![key] as List<dynamic>).cast<Map<String, dynamic>>();

  // ---------------------------------------------------------------------------------------------
  // Routing
  // ---------------------------------------------------------------------------------------------

  Future<http.StreamedResponse> _handle(
      String method, Uri url, Map<String, String> headers, String rawBody) async {
    try {
      Map<String, dynamic> body = {};
      if (rawBody.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawBody);
          if (decoded is Map<String, dynamic>) body = decoded;
        } on FormatException {
          throw _Failure(400, 'Bad Request', 'Malformed request');
        }
      }
      final path = url.path;
      final result = await _route(method, path, url.queryParameters, headers, body);
      return _json(result.$1, result.$2);
    } on _Failure catch (f) {
      return _json(f.status, {
        'timestamp': _clock().toIso8601String(),
        'status': f.status,
        'error': f.error,
        'message': f.message,
        if (f.fieldErrors.isNotEmpty) 'fieldErrors': f.fieldErrors,
      });
    }
  }

  Future<(int, Object?)> _route(String method, String path, Map<String, String> query,
      Map<String, String> headers, Map<String, dynamic> body) async {
    final m = '$method $path';
    if (m == 'GET /api/health') {
      return (200, {'status': 'UP', 'app': 'BusGo offline demo', 'time': _clock().toIso8601String()});
    }
    if (m == 'GET /api/auth/config') return (200, {'googleEnabled': false, 'emailEnabled': false}); // needs a real server
    if (m == 'POST /api/auth/google') {
      throw _Failure(503, 'Service Unavailable', 'Google sign-in is not available in the offline demo.');
    }
    if (m == 'GET /api/places') return (200, _catalog!.search(query['query'] ?? '', query['state'], int.tryParse(query['limit'] ?? '') ?? 20, _servedPlaces()));
    if (m == 'GET /api/places/states') return (200, _catalog!.stateList(_servedPlaces()));
    if (m == 'POST /api/auth/register') return (201, await _register(body));
    if (m == 'POST /api/auth/login') return (200, _login(body));
    if (m == 'POST /api/auth/forgot-password') return (200, await _forgotPassword(body));
    if (m == 'POST /api/auth/reset-password') {
      await _resetPassword(body);
      return (200, null);
    }
    if (method == 'GET' && path == '/api/trips/search') return (200, _searchTrips(query));
    final tripMatch = RegExp(r'^/api/trips/(\d+)(/seats)?$').firstMatch(path);
    if (method == 'GET' && tripMatch != null) {
      final trip = _tripById(int.parse(tripMatch.group(1)!));
      return (200, tripMatch.group(2) == null ? _tripJson(trip) : _seatLayoutJson(trip));
    }

    // Everything below needs a logged-in user.
    final userId = _authenticate(headers);

    if (m == 'GET /api/users/me') return (200, _userJson(_user(userId)));
    if (m == 'PUT /api/users/me') return (200, await _updateProfile(userId, body));
    if (m == 'POST /api/bookings') return (201, await _createBooking(userId, body));
    if (m == 'GET /api/bookings/my') {
      final mine = _list('bookings').where((b) => b['userId'] == userId).toList().reversed;
      return (200, mine.map(_bookingJson).toList());
    }
    final bookingMatch = RegExp(r'^/api/bookings/(\d+)(/cancel)?$').firstMatch(path);
    if (bookingMatch != null) {
      final booking = _ownedBooking(userId, int.parse(bookingMatch.group(1)!));
      if (method == 'GET' && bookingMatch.group(2) == null) return (200, _bookingJson(booking));
      if (method == 'PATCH' && bookingMatch.group(2) != null) return (200, await _cancel(booking));
    }
    if (m == 'GET /api/users/me/passengers') {
      final mine = _list('passengers').where((p) => p['userId'] == userId).toList().reversed;
      return (200, mine.map(_passengerJson).toList());
    }
    if (m == 'POST /api/users/me/passengers') return (201, await _addPassenger(userId, body));
    final passengerMatch = RegExp(r'^/api/users/me/passengers/(\d+)$').firstMatch(path);
    if (method == 'DELETE' && passengerMatch != null) {
      await _deletePassenger(userId, int.parse(passengerMatch.group(1)!));
      return (204, null);
    }
    if (m == 'POST /api/complaints') return (201, await _raiseComplaint(userId, body));
    if (m == 'GET /api/complaints/my') {
      final mine = _list('complaints').where((c) => c['userId'] == userId).toList().reversed;
      return (200, mine.map(_complaintJson).toList());
    }
    throw _Failure(404, 'Not Found', 'No such endpoint: $method $path');
  }

  // ---------------------------------------------------------------------------------------------
  // Auth & profile
  // ---------------------------------------------------------------------------------------------

  Future<Object?> _register(Map<String, dynamic> b) async {
    _check({
      'fullName': _required(b['fullName'], 'Full name is required') ?? _maxLen(b['fullName'], 100, 'Full name must be at most 100 characters'),
      'email': _email(b['email']),
      'phone': _phone(b['phone'], 'Phone is required', 'Phone must be 10 digits'),
      'password': _password(b['password'], 'Password is required'),
    });
    final email = (b['email'] as String).trim().toLowerCase();
    if (_list('users').any((u) => u['email'] == email)) {
      throw _Failure(409, 'Conflict', 'An account with this email already exists');
    }
    final salt = _salt();
    final user = {
      'id': _newId(),
      'fullName': (b['fullName'] as String).trim(),
      'email': email,
      'phone': b['phone'],
      'salt': salt,
      'hash': _hash(b['password'] as String, salt),
    };
    _list('users').add(user);
    await _save();
    return {'token': _tokenFor(user['id'] as int), 'user': _userJson(user)};
  }

  Object? _login(Map<String, dynamic> b) {
    _check({
      'identifier': _required(b['identifier'], 'Email or mobile number is required'),
      'password': _required(b['password'], 'Password is required'),
    });
    final id = (b['identifier'] as String).trim();
    final candidates = id.contains('@')
        ? _list('users').where((u) => (u['email'] as String) == id.toLowerCase())
        : _list('users').where((u) => u['phone'] == id);
    for (final u in candidates) {
      if (_hash(b['password'] as String, u['salt'] as String) == u['hash']) {
        return {'token': _tokenFor(u['id'] as int), 'user': _userJson(u)};
      }
    }
    throw _Failure(401, 'Unauthorized', 'Invalid email/mobile number or password');
  }

  // The offline build cannot send email, so "forgot password" shows the one-time code on screen (and says so).
  // The rules match the Spring backend: 6 digits, 15 minutes, one use, 5 wrong guesses.
  static const _resetMinutes = 15;
  static const _resetMaxAttempts = 5;
  static const _badCode = 'This code is invalid or has expired. Please request a new one.';

  Future<Object?> _forgotPassword(Map<String, dynamic> b) async {
    _check({'email': _email(b['email'])});
    final email = (b['email'] as String).trim().toLowerCase();
    final codes = (_db!.putIfAbsent('resetCodes', () => <String, dynamic>{}) as Map<String, dynamic>);
    String? shown;
    if (_list('users').any((u) => u['email'] == email)) {
      shown = (Random.secure().nextInt(1000000)).toString().padLeft(6, '0');
      codes[email] = {
        'code': shown,
        'expires': _clock().add(const Duration(minutes: _resetMinutes)).toIso8601String(),
        'attempts': 0,
        'used': false,
      };
      await _save();
    }
    // Same wording whether or not the email exists (like the real server). The code is only handed back for
    // registered emails, which is acceptable here because this build keeps every account on this one phone.
    return {
      'message': 'If that email is registered, we have sent a 6-digit code. It expires in a few minutes.',
      'offlineCode': ?shown,
    };
  }

  Future<void> _resetPassword(Map<String, dynamic> b) async {
    _check({
      'email': _email(b['email']),
      'code': _required(b['code'], 'Enter the 6-digit code from the email') ??
          (RegExp(r'^\d{6}$').hasMatch(b['code'] as String) ? null : 'The code is 6 digits'),
      'newPassword': _password(b['newPassword'], 'New password is required'),
    });
    final email = (b['email'] as String).trim().toLowerCase();
    final codes = (_db!.putIfAbsent('resetCodes', () => <String, dynamic>{}) as Map<String, dynamic>);
    final entry = codes[email] as Map<String, dynamic>?;
    final users = _list('users').where((u) => u['email'] == email);
    if (entry == null || users.isEmpty) throw _Failure(400, 'Bad Request', _badCode);

    final expired = !_clock().isBefore(DateTime.parse(entry['expires'] as String));
    if (entry['used'] == true || (entry['attempts'] as int) >= _resetMaxAttempts || expired) {
      throw _Failure(400, 'Bad Request', _badCode);
    }
    if (entry['code'] != b['code']) {
      entry['attempts'] = (entry['attempts'] as int) + 1;
      await _save();
      throw _Failure(400, 'Bad Request', _badCode);
    }
    entry['used'] = true;
    final user = users.first;
    user['salt'] = _salt();
    user['hash'] = _hash(b['newPassword'] as String, user['salt'] as String);
    await _save();
  }
  Future<Object?> _updateProfile(int userId, Map<String, dynamic> b) async {
    _check({
      'fullName': _required(b['fullName'], 'Full name is required') ?? _maxLen(b['fullName'], 100, 'Full name must be at most 100 characters'),
      'phone': _phone(b['phone'], 'Phone is required', 'Phone must be 10 digits'),
    });
    final user = _user(userId);
    user['fullName'] = (b['fullName'] as String).trim();
    user['phone'] = b['phone'];
    await _save();
    return _userJson(user);
  }

  String _tokenFor(int userId) => 'offline-$userId';

  int _authenticate(Map<String, String> headers) {
    final auth = headers['Authorization'] ?? headers['authorization'] ?? '';
    final match = RegExp(r'^Bearer offline-(\d+)$').firstMatch(auth);
    final id = match == null ? null : int.parse(match.group(1)!);
    if (id == null || !_list('users').any((u) => u['id'] == id)) {
      throw _Failure(401, 'Unauthorized', 'Please log in to continue');
    }
    return id;
  }

  Map<String, dynamic> _user(int id) => _list('users').firstWhere((u) => u['id'] == id);

  Map<String, dynamic> _userJson(Map<String, dynamic> u) =>
      {'id': u['id'], 'fullName': u['fullName'], 'email': u['email'], 'phone': u['phone']};

  String _salt() {
    final r = Random.secure();
    return base64Url.encode(List<int>.generate(12, (_) => r.nextInt(256)));
  }

  String _hash(String password, String salt) {
    var digest = sha256.convert(utf8.encode('$salt:$password')).bytes;
    for (var i = 0; i < 2000; i++) {
      digest = sha256.convert([...digest, ...utf8.encode(salt)]).bytes;
    }
    return base64Url.encode(digest);
  }

  // ---------------------------------------------------------------------------------------------
  // Trips (generated, never stored)
  // ---------------------------------------------------------------------------------------------

  // A trip id is epochDay * 100000 + template index, so ids are stable from one day to the next.
  // Older versions of the app used epochDay * 1000 (only 1,000 routes fitted). Those ids are about 2e7 while the
  // new ones are about 2e9, so both can be told apart and bookings made earlier still open correctly.
  static const _idBlock = 100000;
  static const _legacyIdBlock = 1000;
  static const _legacyIdLimit = 100000000;

  _Trip _tripById(int id) {
    final block = id < _legacyIdLimit ? _legacyIdBlock : _idBlock;
    final template = id % block;
    final epochDay = id ~/ block;
    if (template >= _templates.length || epochDay < 1) {
      throw _Failure(404, 'Not Found', 'Trip $id not found');
    }
    final t = _templates[template];
    final day = DateTime.utc(1970, 1, 1).add(Duration(days: epochDay));
    final parts = t.departure.split(':');
    final departure = DateTime(day.year, day.month, day.day, int.parse(parts[0]), int.parse(parts[1]));
    return _Trip(id, t, departure);
  }

  int _epochDay(DateTime d) => DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(1970, 1, 1)).inDays;

  List<Map<String, dynamic>> _searchTrips(Map<String, String> q) {
    // "bangalore" and "BENGALURU" both become "Bengaluru" (same as the Spring backend).
    final from = _catalog!.canonicalName(q['source'] ?? '');
    final to = _catalog!.canonicalName(q['destination'] ?? '');
    if (from.isEmpty || to.isEmpty) throw _Failure(400, 'Bad Request', 'Source and destination are required');
    if (from.toLowerCase() == to.toLowerCase()) {
      throw _Failure(400, 'Bad Request', 'Source and destination must be different');
    }
    final date = DateTime.tryParse(q['date'] ?? '');
    if (date == null) throw _Failure(400, 'Bad Request', 'A valid date (YYYY-MM-DD) is required');

    final now = _clock();
    final today = _epochDay(now);
    final day = _epochDay(date);
    if (day < today || day >= today + _daysAhead) return [];

    final result = <Map<String, dynamic>>[];
    for (var i = 0; i < _templates.length; i++) {
      final t = _templates[i];
      if (t.source.toLowerCase() != from.toLowerCase() || t.destination.toLowerCase() != to.toLowerCase()) continue;
      final trip = _tripById(day * _idBlock + i);
      if (!trip.departure.isAfter(now)) continue;
      if (_available(trip) > 0) result.add(_tripJson(trip));
    }
    result.sort((a, b) => (a['departureTime'] as String).compareTo(b['departureTime'] as String));
    return result;
  }

  /// Lower-case names of places that have at least one demo route.
  Set<String> _servedPlaces() => {
        for (final t in _templates) ...[t.source.toLowerCase(), t.destination.toLowerCase()],
      };

  /// Seat numbers pre-sold to imaginary other customers (deterministic per trip).
  Set<String> _presold(_Trip trip) {
    final seats = _layout(trip.template.type);
    final count = (seats.length * trip.template.bookedPercent / 100).round();
    final order = List<int>.generate(seats.length, (i) => i)..shuffle(Random(trip.id));
    return {for (var i = 0; i < count; i++) seats[order[i]].number};
  }

  Set<String> _taken(_Trip trip) {
    final soldSeats = _db!['soldSeats'] as Map<String, dynamic>;
    final sold = soldSeats['${trip.id}'] as List<dynamic>? ?? const [];
    // Seats sold by an older version of the app were stored under the old, shorter trip id.
    final legacyId = trip.id >= _legacyIdLimit ? (trip.id ~/ _idBlock) * _legacyIdBlock + trip.id % _idBlock : null;
    final legacy = legacyId == null || trip.id % _idBlock >= _legacyIdBlock
        ? const <dynamic>[]
        : soldSeats['$legacyId'] as List<dynamic>? ?? const [];
    return {..._presold(trip), ...sold.cast<String>(), ...legacy.cast<String>()};
  }

  int _available(_Trip trip) => _layout(trip.template.type).length - _taken(trip).length;

  Map<String, dynamic> _tripJson(_Trip trip) {
    final t = trip.template;
    final op = _operators[t.operator];
    return {
      'tripId': trip.id,
      'operatorName': op.$1,
      'operatorRating': double.parse(op.$2),
      'busType': t.type,
      'source': t.source,
      'destination': t.destination,
      'departureTime': trip.departure.toIso8601String(),
      'arrivalTime': trip.departure.add(Duration(minutes: t.durationMinutes)).toIso8601String(),
      'durationMinutes': t.durationMinutes,
      'fare': t.fare.toDouble(),
      'availableSeats': _available(trip),
      'totalSeats': _layout(t.type).length,
      'boardingPoint': _boarding[t.source] ?? '${t.source} Bus Stand',
      'droppingPoint': _dropping[t.destination] ?? '${t.destination} Bus Stand',
      // Same labelling as the Spring backend: every trip here is sample data and can be booked in this app.
      'provider': 'demo',
      'dataSource': 'DEMO',
      'bookable': true,
    };
  }

  Map<String, dynamic> _seatLayoutJson(_Trip trip) {
    final type = trip.template.type;
    final sleeper = type.contains('SLEEPER');
    final seats = _layout(type);
    final taken = _taken(trip);
    return {
      'tripId': trip.id,
      'busType': type,
      'decks': sleeper ? 2 : 1,
      'rows': sleeper ? 5 : 10,
      'columns': sleeper ? 3 : 4,
      'aisleAfterColumn': sleeper ? 1 : 2,
      'availableSeats': seats.length - taken.length,
      'seats': [
        for (final s in seats)
          {
            'seatNumber': s.number,
            'deck': s.deck,
            'row': s.row,
            'column': s.col,
            'status': taken.contains(s.number) ? 'BOOKED' : 'AVAILABLE',
          }
      ],
    };
  }

  /// Seater: 10 rows x 4 columns (2+2). Sleeper: two decks of 5 rows x 3 columns (1+2).
  List<_Seat> _layout(String type) {
    final seats = <_Seat>[];
    if (type.contains('SLEEPER')) {
      for (final deck in ['LOWER', 'UPPER']) {
        final prefix = deck == 'LOWER' ? 'L' : 'U';
        for (var row = 1; row <= 5; row++) {
          for (var col = 1; col <= 3; col++) {
            seats.add(_Seat('$prefix$row${String.fromCharCode(64 + col)}', deck, row, col));
          }
        }
      }
    } else {
      for (var row = 1; row <= 10; row++) {
        for (var col = 1; col <= 4; col++) {
          seats.add(_Seat('$row${String.fromCharCode(64 + col)}', 'LOWER', row, col));
        }
      }
    }
    return seats;
  }

  // ---------------------------------------------------------------------------------------------
  // Bookings
  // ---------------------------------------------------------------------------------------------

  static const _paymentMethods = {'UPI_DEMO', 'CARD_DEMO', 'NET_BANKING_DEMO', 'WALLET_DEMO'};
  static const _refChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  Future<Object?> _createBooking(int userId, Map<String, dynamic> b) async {
    final passengers = b['passengers'];
    final errors = <String, String?>{
      'tripId': b['tripId'] is int ? null : 'Trip is required',
      'passengers': passengers is! List || passengers.isEmpty
          ? 'Select at least one seat'
          : passengers.length > 6
              ? 'You can book at most 6 seats at a time'
              : null,
      'contactPhone': _phone(b['contactPhone'], 'Contact phone is required', 'Phone must be 10 digits'),
      'contactEmail': _email(b['contactEmail'], 'Contact email is required'),
      'paymentMethod': _paymentMethods.contains(b['paymentMethod']) ? null : 'Payment method is required',
    };
    _check(errors);
    final list = passengers as List<dynamic>;
    for (final raw in list) {
      final p = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
      _check({
        'passengers.seatNumber': _required(p['seatNumber'], 'Seat number is required'),
        'passengers.name': _required(p['name'], 'Passenger name is required') ?? _maxLen(p['name'], 100, 'Passenger name must be at most 100 characters'),
        'passengers.age': p['age'] is int && p['age'] >= 1 && p['age'] <= 120 ? null : 'Age must be between 1 and 120',
        'passengers.gender': const {'MALE', 'FEMALE', 'OTHER'}.contains(p['gender']) ? null : 'Gender must be MALE, FEMALE or OTHER',
      });
    }

    final trip = _tripById(b['tripId'] as int);
    final now = _clock();
    final day = _epochDay(trip.departure);
    if (day < _epochDay(now) || day >= _epochDay(now) + _daysAhead + 1) {
      throw _Failure(404, 'Not Found', 'Trip ${trip.id} not found');
    }
    if (!trip.departure.isAfter(now)) throw _Failure(400, 'Bad Request', 'This bus has already departed');

    final seatNumbers = [for (final p in list) ((p as Map<String, dynamic>)['seatNumber'] as String).trim().toUpperCase()];
    if (seatNumbers.toSet().length != seatNumbers.length) {
      throw _Failure(400, 'Bad Request', 'The same seat was selected more than once');
    }
    final valid = _layout(trip.template.type).map((s) => s.number).toSet();
    final unknown = seatNumbers.where((n) => !valid.contains(n)).toList();
    if (unknown.isNotEmpty) {
      throw _Failure(400, 'Bad Request', 'Unknown seat(s) for this trip: ${unknown.join(', ')}');
    }
    final taken = _taken(trip);
    final clash = seatNumbers.where(taken.contains).toList();
    if (clash.isNotEmpty) {
      throw _Failure(409, 'Conflict', 'Seat(s) no longer available: ${clash.join(', ')}');
    }

    final sold = _db!['soldSeats'] as Map<String, dynamic>;
    sold['${trip.id}'] = [...(sold['${trip.id}'] as List<dynamic>? ?? const []), ...seatNumbers];

    final booking = {
      'id': _newId(),
      'userId': userId,
      'reference': _newReference(),
      'status': 'CONFIRMED',
      'tripId': trip.id,
      'total': trip.template.fare * seatNumbers.length,
      'refund': null,
      'paymentMethod': b['paymentMethod'],
      'contactPhone': b['contactPhone'],
      'contactEmail': (b['contactEmail'] as String).trim(),
      'bookedAt': now.toIso8601String(),
      'cancelledAt': null,
      'passengers': [
        for (var i = 0; i < list.length; i++)
          {
            'seatNumber': seatNumbers[i],
            'name': ((list[i] as Map<String, dynamic>)['name'] as String).trim(),
            'age': (list[i] as Map<String, dynamic>)['age'],
            'gender': (list[i] as Map<String, dynamic>)['gender'],
          }
      ],
    };
    _list('bookings').add(booking);
    await _save();
    return _bookingJson(booking);
  }

  String _newReference() {
    final r = Random.secure();
    while (true) {
      final ref = 'BG${List.generate(8, (_) => _refChars[r.nextInt(_refChars.length)]).join()}';
      if (!_list('bookings').any((x) => x['reference'] == ref)) return ref;
    }
  }

  Map<String, dynamic> _ownedBooking(int userId, int id) {
    final matches = _list('bookings').where((b) => b['id'] == id);
    if (matches.isEmpty) throw _Failure(404, 'Not Found', 'Booking $id not found');
    if (matches.first['userId'] != userId) {
      throw _Failure(403, 'Forbidden', 'You do not have access to this booking');
    }
    return matches.first;
  }

  Future<Object?> _cancel(Map<String, dynamic> booking) async {
    if (booking['status'] == 'CANCELLED') throw _Failure(409, 'Conflict', 'This booking is already cancelled');
    final trip = _tripById(booking['tripId'] as int);
    final now = _clock();
    if (!trip.departure.isAfter(now)) {
      throw _Failure(400, 'Bad Request', 'This bus has already departed and cannot be cancelled');
    }
    // Demo policy: 24h+ before departure 90%, 6-24h 50%, under 6h nothing.
    final hours = trip.departure.difference(now).inHours;
    final percent = hours >= 24 ? 90 : (hours >= 6 ? 50 : 0);
    final total = (booking['total'] as num).toDouble();
    booking['refund'] = (total * percent / 100 * 100).round() / 100;
    booking['status'] = 'CANCELLED';
    booking['cancelledAt'] = now.toIso8601String();

    final sold = _db!['soldSeats'] as Map<String, dynamic>;
    final released = {for (final p in booking['passengers'] as List<dynamic>) (p as Map<String, dynamic>)['seatNumber']};
    final remaining = (sold['${trip.id}'] as List<dynamic>? ?? const []).where((s) => !released.contains(s)).toList();
    sold['${trip.id}'] = remaining;
    await _save();
    return _bookingJson(booking);
  }

  Map<String, dynamic> _bookingJson(Map<String, dynamic> b) {
    final trip = _tripById(b['tripId'] as int);
    final t = trip.template;
    final upcoming = b['status'] == 'CONFIRMED' && trip.departure.isAfter(_clock());
    return {
      'bookingId': b['id'],
      'bookingReference': b['reference'],
      'status': b['status'],
      'upcoming': upcoming,
      'tripId': trip.id,
      'operatorName': _operators[t.operator].$1,
      'busType': t.type,
      'source': t.source,
      'destination': t.destination,
      'departureTime': trip.departure.toIso8601String(),
      'arrivalTime': trip.departure.add(Duration(minutes: t.durationMinutes)).toIso8601String(),
      'boardingPoint': _boarding[t.source] ?? '${t.source} Bus Stand',
      'droppingPoint': _dropping[t.destination] ?? '${t.destination} Bus Stand',
      'totalAmount': (b['total'] as num).toDouble(),
      'refundAmount': (b['refund'] as num?)?.toDouble(),
      'paymentMethod': b['paymentMethod'],
      'contactPhone': b['contactPhone'],
      'contactEmail': b['contactEmail'],
      'bookedAt': b['bookedAt'],
      'cancelledAt': b['cancelledAt'],
      'passengers': b['passengers'],
    };
  }

  // ---------------------------------------------------------------------------------------------
  // Saved passengers & complaints
  // ---------------------------------------------------------------------------------------------

  Future<Object?> _addPassenger(int userId, Map<String, dynamic> b) async {
    _check({
      'name': _required(b['name'], 'Passenger name is required') ?? _maxLen(b['name'], 100, 'Passenger name must be at most 100 characters'),
      'age': b['age'] is int ? (b['age'] < 1 ? 'Age must be at least 1' : (b['age'] > 120 ? 'Age must be at most 120' : null)) : 'Passenger age is required',
      'gender': const {'MALE', 'FEMALE', 'OTHER'}.contains(b['gender']) ? null : 'Gender must be MALE, FEMALE or OTHER',
    });
    final name = (b['name'] as String).trim();
    final mine = _list('passengers').where((p) => p['userId'] == userId).toList();
    if (mine.any((p) => (p['name'] as String).toLowerCase() == name.toLowerCase() && p['age'] == b['age'] && p['gender'] == b['gender'])) {
      throw _Failure(409, 'Conflict', 'This passenger is already saved');
    }
    if (mine.length >= _maxSavedPassengers) {
      throw _Failure(400, 'Bad Request', 'You can save at most $_maxSavedPassengers passengers. Delete one first.');
    }
    final p = {'id': _newId(), 'userId': userId, 'name': name, 'age': b['age'], 'gender': b['gender']};
    _list('passengers').add(p);
    await _save();
    return _passengerJson(p);
  }

  Future<void> _deletePassenger(int userId, int id) async {
    final matches = _list('passengers').where((p) => p['id'] == id).toList();
    if (matches.isEmpty) throw _Failure(404, 'Not Found', 'Saved passenger not found');
    if (matches.first['userId'] != userId) {
      throw _Failure(403, 'Forbidden', 'You do not have access to this passenger');
    }
    _list('passengers').remove(matches.first);
    await _save();
  }

  Map<String, dynamic> _passengerJson(Map<String, dynamic> p) =>
      {'id': p['id'], 'name': p['name'], 'age': p['age'], 'gender': p['gender']};

  Future<Object?> _raiseComplaint(int userId, Map<String, dynamic> b) async {
    final ref = b['bookingReference'];
    _check({
      'bookingReference': ref is String && ref.length > 20 ? 'Booking reference is too long' : null,
      'subject': _required(b['subject'], 'Subject is required') ?? _maxLen(b['subject'], 120, 'Subject must be at most 120 characters'),
      'message': _required(b['message'], 'Please describe the problem') ??
          ((b['message'] as String).length < 10 || (b['message'] as String).length > 1000
              ? 'Description must be 10 to 1000 characters'
              : null),
    });
    String? reference;
    if (ref is String && ref.trim().isNotEmpty) {
      reference = ref.trim().toUpperCase();
      final owns = _list('bookings').any((x) => x['userId'] == userId && x['reference'] == reference);
      if (!owns) throw _Failure(400, 'Bad Request', 'Booking $reference was not found in your bookings');
    }
    final id = _newId();
    final c = {
      'id': id,
      'userId': userId,
      'reference': 'CMP${id.toString().padLeft(5, '0')}',
      'bookingReference': reference,
      'subject': (b['subject'] as String).trim(),
      'message': (b['message'] as String).trim(),
      'status': 'OPEN',
      'createdAt': _clock().toIso8601String(),
    };
    _list('complaints').add(c);
    await _save();
    return _complaintJson(c);
  }

  Map<String, dynamic> _complaintJson(Map<String, dynamic> c) => {
        'id': c['id'],
        'reference': c['reference'],
        'bookingReference': c['bookingReference'],
        'subject': c['subject'],
        'message': c['message'],
        'status': c['status'],
        'createdAt': c['createdAt'],
      };

  // ---------------------------------------------------------------------------------------------
  // Validation helpers (messages match the backend's Bean Validation messages)
  // ---------------------------------------------------------------------------------------------

  void _check(Map<String, String?> errors) {
    final failed = {for (final e in errors.entries) if (e.value != null) e.key: e.value!};
    if (failed.isNotEmpty) throw _Failure(400, 'Bad Request', 'Validation failed', failed);
  }

  String? _required(Object? v, String message) => v is String && v.trim().isNotEmpty ? null : message;

  String? _maxLen(Object? v, int max, String message) => v is String && v.length > max ? message : null;

  String? _email(Object? v, [String requiredMsg = 'Email is required']) {
    final missing = _required(v, requiredMsg);
    if (missing != null) return missing;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v as String).trim()) ? null : 'Enter a valid email address';
  }

  String? _phone(Object? v, String requiredMsg, String formatMsg) =>
      _required(v, requiredMsg) ?? (RegExp(r'^\d{10}$').hasMatch((v as String).trim()) ? null : formatMsg);

  String? _password(Object? v, String requiredMsg) =>
      _required(v, requiredMsg) ?? ((v as String).length < 8 || v.length > 72 ? 'Password must be 8 to 72 characters' : null);

  http.StreamedResponse _json(int status, Object? body) {
    final bytes = body == null ? <int>[] : utf8.encode(jsonEncode(body));
    return http.StreamedResponse(Stream.value(bytes), status,
        contentLength: bytes.length, headers: {'content-type': 'application/json; charset=utf-8'});
  }

  // ---------------------------------------------------------------------------------------------
  // Demo data (same operators, routes, fares and times as the Spring backend's DemoDataService)
  // ---------------------------------------------------------------------------------------------

  static const _operators = [
    ('SkyLine Travels', '4.4'),
    ('GreenLine Express', '4.1'),
    ('BlueWave Tours', '4.6'),
    ('Sunrise Travels', '3.9'),
    ('MetroLink Coaches', '4.2'),
    ('Royal Cruiser', '4.5'),
  ];

  static const _boarding = {
    'Kurnool': 'Kurnool Bus Stand', 'Hyderabad': 'Ameerpet X Roads', 'Bengaluru': 'Majestic Bus Station',
    'Chennai': 'Koyambedu CMBT', 'Vijayawada': 'Pandit Nehru Bus Station', 'Delhi': 'Kashmere Gate ISBT',
    'Jaipur': 'Sindhi Camp Bus Stand', 'Mumbai': 'Dadar East', 'Pune': 'Swargate',
    'Visakhapatnam': 'RTC Complex', 'Tirupati': 'Tirupati Central Bus Stand', 'Mysuru': 'Mysuru City Bus Stand',
    'Coimbatore': 'Gandhipuram Bus Stand', 'Madurai': 'Mattuthavani Bus Stand', 'Panaji': 'Panaji Kadamba Bus Stand',
    'Ahmedabad': 'Geeta Mandir', 'Chandigarh': 'ISBT Sector 17', 'Agra': 'Idgah Bus Stand',
    'Warangal': 'Hanamkonda Bus Stand', 'Karimnagar': 'Karimnagar Bus Stand', 'Nizamabad': 'Nizamabad Bus Stand',
    'Guntur': 'Guntur Bus Station', 'Nellore': 'Nellore Bus Stand', 'Rajahmundry': 'Rajahmundry Bus Stand',
    'Anantapur': 'Anantapur Bus Stand', 'Kadapa': 'Kadapa Bus Stand', 'Mahbubnagar': 'Mahbubnagar Bus Stand',
  };

  static const _dropping = {
    'Kurnool': 'Kurnool Bus Stand', 'Hyderabad': 'MGBS', 'Bengaluru': 'Madiwala', 'Chennai': 'Guindy',
    'Vijayawada': 'Benz Circle', 'Delhi': 'Anand Vihar ISBT', 'Jaipur': 'Narayan Singh Circle',
    'Mumbai': 'Borivali', 'Pune': 'Shivajinagar', 'Visakhapatnam': 'Maddilapalem',
    'Tirupati': 'Alipiri Bus Point', 'Mysuru': 'Mysuru Railway Station', 'Coimbatore': 'Ukkadam Bus Stand',
    'Madurai': 'Periyar Bus Stand', 'Panaji': 'Mapusa Bus Stand', 'Ahmedabad': 'Paldi',
    'Chandigarh': 'ISBT Sector 43', 'Agra': 'ISBT Agra',
    'Warangal': 'Warangal Bus Station', 'Karimnagar': 'Karimnagar Bus Stand', 'Nizamabad': 'Nizamabad Bus Stand',
    'Guntur': 'Guntur Bus Station', 'Nellore': 'Nellore Bus Stand', 'Rajahmundry': 'Rajahmundry Bus Stand',
    'Anantapur': 'Anantapur Bus Stand', 'Kadapa': 'Kadapa Bus Stand', 'Mahbubnagar': 'Mahbubnagar Bus Stand',
  };

  static List<_Template> _buildTemplates(List<List<String>> routeRows) {
    const ac = 'AC_SEATER', non = 'NON_AC_SEATER', acS = 'AC_SLEEPER', nonS = 'NON_AC_SLEEPER';
    // source, destination, operator, type, departure, minutes, fare, % pre-sold (100 = sold out)
    final all = <_Template>[
      _Template('Kurnool', 'Hyderabad', 0, ac, '06:30', 270, 550, 20),
      _Template('Kurnool', 'Hyderabad', 1, non, '09:00', 270, 420, 45),
      _Template('Kurnool', 'Hyderabad', 2, acS, '21:30', 270, 899, 30),
      _Template('Kurnool', 'Hyderabad', 5, nonS, '23:00', 270, 699, 93),
      _Template('Kurnool', 'Hyderabad', 3, ac, '23:45', 270, 650, 100),
      _Template('Hyderabad', 'Kurnool', 0, ac, '07:00', 270, 550, 10),
      _Template('Hyderabad', 'Kurnool', 1, non, '18:30', 270, 430, 70),
      _Template('Hyderabad', 'Kurnool', 2, acS, '22:00', 270, 899, 55),
      _Template('Hyderabad', 'Bengaluru', 0, ac, '21:00', 540, 1100, 50),
      _Template('Hyderabad', 'Bengaluru', 4, non, '19:30', 540, 820, 25),
      _Template('Hyderabad', 'Bengaluru', 5, acS, '20:00', 540, 1350, 35),
      _Template('Hyderabad', 'Bengaluru', 3, nonS, '22:00', 540, 950, 90),
      _Template('Bengaluru', 'Hyderabad', 1, non, '20:00', 540, 800, 60),
      _Template('Bengaluru', 'Hyderabad', 2, acS, '21:00', 540, 1400, 40),
      _Template('Bengaluru', 'Hyderabad', 5, ac, '22:30', 540, 1150, 15),
      _Template('Bengaluru', 'Chennai', 0, ac, '07:00', 390, 690, 20),
      _Template('Bengaluru', 'Chennai', 4, non, '13:30', 390, 480, 50),
      _Template('Bengaluru', 'Chennai', 2, acS, '23:00', 390, 990, 30),
      _Template('Bengaluru', 'Chennai', 1, nonS, '22:30', 390, 780, 92),
      _Template('Chennai', 'Bengaluru', 5, ac, '06:30', 390, 700, 25),
      _Template('Chennai', 'Bengaluru', 3, non, '14:00', 390, 470, 40),
      _Template('Chennai', 'Bengaluru', 0, acS, '23:30', 390, 1000, 45),
      _Template('Hyderabad', 'Vijayawada', 4, ac, '06:00', 300, 580, 20),
      _Template('Hyderabad', 'Vijayawada', 1, non, '10:30', 300, 410, 55),
      _Template('Hyderabad', 'Vijayawada', 0, acS, '22:30', 300, 850, 35),
      _Template('Hyderabad', 'Vijayawada', 3, nonS, '23:30', 300, 650, 100),
      _Template('Vijayawada', 'Hyderabad', 2, ac, '07:30', 300, 590, 30),
      _Template('Vijayawada', 'Hyderabad', 5, acS, '22:00', 300, 880, 40),
      _Template('Delhi', 'Jaipur', 4, ac, '06:00', 330, 750, 25),
      _Template('Delhi', 'Jaipur', 0, non, '08:30', 330, 520, 50),
      _Template('Delhi', 'Jaipur', 5, acS, '22:00', 330, 1150, 30),
      _Template('Delhi', 'Jaipur', 1, nonS, '23:00', 330, 880, 91),
      _Template('Jaipur', 'Delhi', 2, ac, '07:00', 330, 760, 30),
      _Template('Jaipur', 'Delhi', 3, non, '15:00', 330, 500, 60),
      _Template('Mumbai', 'Pune', 4, ac, '06:00', 210, 450, 20),
      _Template('Mumbai', 'Pune', 0, ac, '14:30', 210, 480, 45),
      _Template('Mumbai', 'Pune', 1, non, '17:00', 210, 320, 65),
      _Template('Mumbai', 'Pune', 5, acS, '22:30', 210, 750, 30),
      _Template('Pune', 'Mumbai', 2, ac, '07:30', 210, 460, 25),
      _Template('Pune', 'Mumbai', 3, non, '18:00', 210, 330, 55),
    ];
    // Extra routes come from assets/data/demo-routes.csv (generated by tools/build_demo_data.py), served in both directions.
    final extra = [for (final r in routeRows) (r[0], r[1], int.parse(r[2]), int.parse(r[3]))];
    int round10(double v) => (v / 10).round() * 10;
    var op = 0;
    for (final r in extra) {
      for (final forward in [true, false]) {
        final from = forward ? r.$1 : r.$2;
        final to = forward ? r.$2 : r.$1;
        final times = forward ? ['06:30', '14:00', '21:30', '23:00'] : ['07:30', '15:00', '22:00', '23:30'];
        all.add(_Template(from, to, op++ % 6, ac, times[0], r.$3, r.$4, 25));
        all.add(_Template(from, to, op++ % 6, non, times[1], r.$3, round10(r.$4 * 0.75), 50));
        all.add(_Template(from, to, op++ % 6, acS, times[2], r.$3, round10(r.$4 * 1.4), 35));
        if (r.$3 >= 480) {
          all.add(_Template(from, to, op++ % 6, nonS, times[3], r.$3, round10(r.$4 * 1.1), 92));
        }
      }
    }
    return List.unmodifiable(all);
  }
}

class _Template {
  const _Template(this.source, this.destination, this.operator, this.type, this.departure,
      this.durationMinutes, this.fare, this.bookedPercent);

  final String source;
  final String destination;
  final int operator;
  final String type;
  final String departure; // HH:mm
  final int durationMinutes;
  final int fare;
  final int bookedPercent;
}

class _Trip {
  const _Trip(this.id, this.template, this.departure);

  final int id;
  final _Template template;
  final DateTime departure;
}

class _Seat {
  const _Seat(this.number, this.deck, this.row, this.col);

  final String number;
  final String deck;
  final int row;
  final int col;
}

class _Failure implements Exception {
  _Failure(this.status, this.error, this.message, [this.fieldErrors = const {}]);

  final int status;
  final String error;
  final String message;
  final Map<String, String> fieldErrors;
}

/// Splits CSV text into rows (header row skipped). Handles quoted fields, like the Spring backend's reader.
List<List<String>> _parseCsv(String text) {
  final rows = <List<String>>[];
  final lines = const LineSplitter().convert(text);
  for (var i = 1; i < lines.length; i++) {
    final line = lines[i];
    if (line.trim().isEmpty) continue;
    final fields = <String>[];
    final current = StringBuffer();
    var quoted = false;
    for (var c = 0; c < line.length; c++) {
      final ch = line[c];
      if (quoted) {
        if (ch == '"' && c + 1 < line.length && line[c + 1] == '"') {
          current.write('"');
          c++;
        } else if (ch == '"') {
          quoted = false;
        } else {
          current.write(ch);
        }
      } else if (ch == '"') {
        quoted = true;
      } else if (ch == ',') {
        fields.add(current.toString());
        current.clear();
      } else {
        current.write(ch);
      }
    }
    fields.add(current.toString());
    rows.add(fields);
  }
  return rows;
}

/// The searchable list of places in India (same data files and ranking as the Spring backend's CityCatalog).
/// A place being listed does NOT mean buses run there; only the demo routes have trips.
class _Catalog {
  _Catalog({required List<List<String>> cities, required List<List<String>> aliases, required List<List<String>> states}) {
    for (final r in cities) {
      final city = _City(r[0], r[1], int.tryParse(r[4]) ?? 0);
      this.cities.add(city);
      byLower[city.name.toLowerCase()] = city;
    }
    for (final r in aliases) {
      aliasToCity[r[0].toLowerCase()] = r[1];
    }
    for (final r in states) {
      this.states.add((r[0], r[1]));
    }
  }

  final List<_City> cities = [];
  final Map<String, _City> byLower = {};
  final Map<String, String> aliasToCity = {};
  final List<(String, String)> states = [];

  String canonicalName(String input) {
    final key = input.trim().toLowerCase();
    if (key.isEmpty) return '';
    final direct = byLower[key];
    if (direct != null) return direct.name;
    final aliased = aliasToCity[key];
    final target = aliased == null ? null : byLower[aliased.toLowerCase()];
    return target?.name ?? input.trim();
  }

  static int _score(String name, String q) {
    if (name == q) return 0;
    if (name.startsWith(q)) return 1;
    if (name.contains(' $q')) return 2;
    return name.contains(q) ? 3 : -1;
  }

  List<Map<String, dynamic>> search(String query, String? state, int limit, Set<String> served) {
    final q = query.trim().toLowerCase();
    final max = limit.clamp(1, 100);
    if (state != null && state.trim().isNotEmpty && !states.any((s) => s.$1.toLowerCase() == state.trim().toLowerCase())) {
      throw _Failure(400, 'Bad Request', 'Unknown state or union territory: ${state.trim()}');
    }
    bool stateOk(_City c) => state == null || state.trim().isEmpty || c.state.toLowerCase() == state.trim().toLowerCase();

    final hits = <_City, int>{};
    for (final c in cities) {
      if (!stateOk(c)) continue;
      final s = q.isEmpty ? 0 : _score(c.name.toLowerCase(), q);
      if (s >= 0) hits[c] = s;
    }
    if (q.isNotEmpty) {
      aliasToCity.forEach((alias, target) {
        final city = byLower[target.toLowerCase()];
        if (alias.startsWith(q) && city != null && stateOk(city)) hits[city] = alias == q ? 0 : 1;
      });
    }
    final sorted = hits.entries.toList()
      ..sort((a, b) {
        final byScore = a.value.compareTo(b.value);
        if (byScore != 0) return byScore;
        final byPop = b.key.population.compareTo(a.key.population);
        return byPop != 0 ? byPop : a.key.name.compareTo(b.key.name);
      });
    return [
      for (final e in sorted.take(max))
        {'name': e.key.name, 'state': e.key.state, 'hasService': served.contains(e.key.name.toLowerCase())},
    ];
  }

  List<Map<String, dynamic>> stateList(Set<String> served) => [
        for (final s in states)
          () {
            final inState = cities.where((c) => c.state == s.$1);
            return {
              'name': s.$1,
              'type': s.$2,
              'placeCount': inState.length,
              'servedPlaceCount': inState.where((c) => served.contains(c.name.toLowerCase())).length,
            };
          }(),
      ];
}

class _City {
  const _City(this.name, this.state, this.population);

  final String name;
  final String state;
  final int population;
}