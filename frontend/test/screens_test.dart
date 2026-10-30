import 'package:busgo/models/search_params.dart';
import 'package:busgo/screens/login_screen.dart';
import 'package:busgo/screens/search_results_screen.dart';
import 'package:busgo/services/api_service.dart';
import 'package:busgo/services/session.dart';
import 'package:busgo/utils/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'test_data.dart';

Widget _app(Widget home) => MaterialApp(theme: AppTheme.light, home: home);

SearchParams get _params =>
    SearchParams(source: 'Kurnool', destination: 'Hyderabad', date: DateTime(2030, 1, 10));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LoginScreen', () {
    testWidgets('shows validation messages for empty fields', (tester) async {
      await tester.pumpWidget(_app(const LoginScreen()));
      await tester.tap(find.text('Login'));
      await tester.pump();
      expect(find.text('Email or mobile number is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('shows the server message when credentials are wrong', (tester) async {
      api = ApiService(
        baseUrl: 'http://test',
        sessionOverride: Session(),
        client: fakeServer((_) async => jsonResponse(
            {'status': 401, 'error': 'Unauthorized', 'message': 'Invalid email or password'}, 401)),
      );
      await tester.pumpWidget(_app(const LoginScreen()));
      await tester.enterText(find.byType(TextFormField).at(0), 'asha@example.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'WrongPassword');
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();
      expect(find.text('Invalid email or password'), findsOneWidget);
    });
  });

  group('SearchResultsScreen', () {
    testWidgets('lists buses returned by the backend', (tester) async {
      api = ApiService(
        baseUrl: 'http://test',
        sessionOverride: Session(),
        client: fakeServer((request) async {
          expect(request.url.path, '/api/trips/search');
          expect(request.url.queryParameters['source'], 'Kurnool');
          expect(request.url.queryParameters['date'], '2030-01-10');
          return jsonResponse([
            tripJson(id: 1, operator: 'SkyLine Travels', seats: 32, fare: 550),
            tripJson(id: 2, operator: 'BlueWave Tours', busType: 'AC_SLEEPER', seats: 2, fare: 899),
          ]);
        }),
      );
      await tester.pumpWidget(_app(SearchResultsScreen(params: _params)));
      await tester.pumpAndSettle();
      expect(find.text('SkyLine Travels'), findsOneWidget);
      expect(find.text('BlueWave Tours'), findsOneWidget);
      expect(find.text('32 seats available'), findsOneWidget);
      expect(find.text('2 seats available'), findsOneWidget);
      expect(find.text('AC Sleeper'), findsOneWidget);
    });

    testWidgets('shows an empty state when no buses are available', (tester) async {
      api = ApiService(
        baseUrl: 'http://test',
        sessionOverride: Session(),
        client: fakeServer((_) async => jsonResponse([])),
      );
      await tester.pumpWidget(_app(SearchResultsScreen(params: _params)));
      await tester.pumpAndSettle();
      expect(find.text('No buses available'), findsOneWidget);
    });

    testWidgets('does not crash when the server is down and Retry works', (tester) async {
      var calls = 0;
      api = ApiService(
        baseUrl: 'http://test',
        sessionOverride: Session(),
        client: fakeServer((_) async {
          calls++;
          if (calls == 1) throw http.ClientException('connection refused');
          return jsonResponse([tripJson(operator: 'GreenLine Express')]);
        }),
      );
      await tester.pumpWidget(_app(SearchResultsScreen(params: _params)));
      await tester.pumpAndSettle();

      expect(find.textContaining('Cannot reach the server'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('GreenLine Express'), findsOneWidget);
      expect(calls, 2);
    });
  });
}

