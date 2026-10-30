import 'package:busgo/services/api_service.dart';
import 'package:busgo/services/session.dart';
import 'package:busgo/widgets/auth_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_data.dart';

/// In the test build no Google client id is supplied (GOOGLE_WEB_CLIENT_ID is empty), exactly like a build where
/// Google Cloud has not been set up yet. The button must say so and must never pretend to work.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('when Google is not configured the button is clearly marked unavailable', (tester) async {
    var requests = 0;
    api = ApiService(
      baseUrl: 'http://test',
      sessionOverride: Session(),
      client: fakeServer((_) async {
        requests++;
        return jsonResponse({'googleEnabled': true});
      }),
    );
    var signedIn = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: GoogleSignInButton(onSignedIn: () => signedIn = true)),
    ));

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.textContaining('Unavailable: Not configured in this build'), findsOneWidget);

    // Tapping explains why instead of doing nothing or pretending to sign in.
    await tester.tap(find.text('Continue with Google'));
    await tester.pump();
    expect(find.textContaining('Google sign-in is unavailable'), findsOneWidget);
    expect(signedIn, isFalse);
    expect(requests, 0, reason: 'no server call is made when this build cannot do Google sign-in');
  });

  testWidgets('the button is announced to screen readers as unavailable', (tester) async {
    final handle = tester.ensureSemantics();
    api = ApiService(baseUrl: 'http://test', sessionOverride: Session(), client: fakeServer((_) async => jsonResponse({})));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: GoogleSignInButton(onSignedIn: () {}))));
    expect(find.bySemanticsLabel(RegExp('Continue with Google, unavailable')), findsOneWidget);
    handle.dispose();
  });
}
