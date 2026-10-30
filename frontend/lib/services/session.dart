import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/payment_method.dart';
import '../models/search_params.dart';
import '../models/user.dart';

/// Who is logged in, plus a few small per-device settings. This is the app's one piece of shared state,
/// kept deliberately small: a ChangeNotifier that remembers values between app launches.
class Session extends ChangeNotifier {
  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';
  static const _onboardingKey = 'onboarding_seen';
  static const _paymentKey = 'preferred_payment';
  static const _avatarKey = 'avatar_base64';

  String? _token;
  User? _user;
  bool _onboardingSeen = false;
  PaymentMethod _preferredPayment = PaymentMethod.upi;
  Uint8List? _avatar;

  /// Return leg of a round trip the user still has to book (only kept in memory).
  SearchParams? pendingReturn;

  String? get token => _token;
  User? get user => _user;
  bool get isLoggedIn => _token != null;
  bool get onboardingSeen => _onboardingSeen;
  PaymentMethod get preferredPayment => _preferredPayment;

  /// Profile photo chosen on this device (not uploaded anywhere).
  Uint8List? get avatar => _avatar;

  /// Reads saved values. Never throws: if storage fails the user simply starts logged out.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_tokenKey);
      final userJson = prefs.getString(_userKey);
      _user = userJson == null ? null : User.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
      _onboardingSeen = prefs.getBool(_onboardingKey) ?? false;
      final pay = prefs.getString(_paymentKey);
      _preferredPayment = PaymentMethod.values.firstWhere((m) => m.apiValue == pay, orElse: () => PaymentMethod.upi);
      final avatar = prefs.getString(_avatarKey);
      _avatar = avatar == null ? null : base64Decode(avatar);
    } catch (_) {
      _token = null;
      _user = null;
    }
    notifyListeners();
  }

  Future<void> signIn(String token, User user) async {
    _token = token;
    _user = user;
    notifyListeners();
    await _save((p) async {
      await p.setString(_tokenKey, token);
      await p.setString(_userKey, jsonEncode(user.toJson()));
    });
  }

  Future<void> updateUser(User user) async {
    _user = user;
    notifyListeners();
    await _save((p) => p.setString(_userKey, jsonEncode(user.toJson())));
  }

  Future<void> signOut() async {
    _token = null;
    _user = null;
    _avatar = null;
    pendingReturn = null;
    notifyListeners();
    await _save((p) async {
      await p.remove(_tokenKey);
      await p.remove(_userKey);
      await p.remove(_avatarKey);
    });
  }

  Future<void> markOnboardingSeen() async {
    _onboardingSeen = true;
    await _save((p) => p.setBool(_onboardingKey, true));
  }

  Future<void> setPreferredPayment(PaymentMethod method) async {
    _preferredPayment = method;
    notifyListeners();
    await _save((p) => p.setString(_paymentKey, method.apiValue));
  }

  Future<void> setAvatar(Uint8List? bytes) async {
    _avatar = bytes;
    notifyListeners();
    await _save((p) async {
      if (bytes == null) {
        await p.remove(_avatarKey);
      } else {
        await p.setString(_avatarKey, base64Encode(bytes));
      }
    });
  }

  Future<void> _save(Future<void> Function(SharedPreferences) action) async {
    try {
      await action(await SharedPreferences.getInstance());
    } catch (_) {
      // Storage problems must not break the app; the in-memory session still works.
    }
  }
}

/// The single app-wide session (simple alternative to a state-management package).
final Session session = Session();
