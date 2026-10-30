import 'package:busgo/screens/forgot_password_screen.dart';
import 'package:busgo/screens/login_screen.dart';
import 'package:busgo/services/api_service.dart';
import 'package:busgo/services/session.dart';
import 'package:busgo/utils/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_data.dart';

Widget _app(Widget home) => MaterialApp(theme: AppTheme.light, home: home);

/// Pressing Enter (the keyboard's "done" key) must submit a form exactly like tapping its button.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Enter in the password field logs in', (tester) async {
    final calls = <String>[];
    api = ApiService(
      baseUrl: 'http://test',
      sessionOverride: Session(),
      client: fakeServer((request) async {
        calls.add(request.url.path);
        return jsonResponse({'status': 401, 'error': 'Unauthorized', 'message': 'Invalid email/mobile number or password'}, 401);
      }),
    );
    await tester.pumpWidget(_app(const LoginScreen()));

    await tester.enterText(find.byType(TextFormField).at(0), 'asha@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'Password123');
    await tester.testTextInput.receiveAction(TextInputAction.done); // the Enter key
    await tester.pumpAndSettle();

    expect(calls, ['/api/auth/login'], reason: 'Enter must send the login request');
    expect(find.text('Invalid email/mobile number or password'), findsOneWidget);
  });

  testWidgets('pressing Enter twice quickly sends only one login request', (tester) async {
    var requests = 0;
    api = ApiService(
      baseUrl: 'http://test',
      sessionOverride: Session(),
      client: fakeServer((request) async {
        requests++;
        return jsonResponse({'status': 401, 'error': 'Unauthorized', 'message': 'Invalid email/mobile number or password'}, 401);
      }),
    );
    await tester.pumpWidget(_app(const LoginScreen()));
    await tester.enterText(find.byType(TextFormField).at(0), 'asha@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'Password123');

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(requests, 1);
  });

  testWidgets('Enter with an empty password shows the validation message instead of sending', (tester) async {
    var requests = 0;
    api = ApiService(
      baseUrl: 'http://test',
      sessionOverride: Session(),
      client: fakeServer((request) async {
        requests++;
        return jsonResponse({});
      }),
    );
    await tester.pumpWidget(_app(const LoginScreen()));
    await tester.enterText(find.byType(TextFormField).at(0), 'asha@example.com');
    await tester.tap(find.byType(TextFormField).at(1));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(requests, 0);
    expect(find.text('Password is required'), findsOneWidget);
  });

  testWidgets('Enter in the forgot-password email field sends the code', (tester) async {
    final calls = <String>[];
    api = ApiService(
      baseUrl: 'http://test',
      sessionOverride: Session(),
      client: fakeServer((request) async {
        calls.add(request.url.path);
        if (request.url.path == '/api/auth/config') return jsonResponse({'googleEnabled': false, 'emailEnabled': true});
        return jsonResponse({'message': 'If that email is registered, we have sent a 6-digit code.'});
      }),
    );
    await tester.pumpWidget(_app(const ForgotPasswordScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'asha@example.com');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(calls, contains('/api/auth/forgot-password'));
    expect(find.text('6-digit code'), findsOneWidget, reason: 'the screen moves on to step 2');
  });
}
