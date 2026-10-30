import 'dart:convert';
import 'package:busgo/models/app_notification.dart';
import 'package:busgo/models/booking.dart';
import 'package:busgo/models/bus_type.dart';
import 'package:busgo/models/payment_method.dart';
import 'package:busgo/screens/forgot_password_screen.dart';
import 'package:busgo/screens/payment_methods_screen.dart';
import 'package:busgo/screens/saved_passengers_screen.dart';
import 'package:busgo/services/api_service.dart';
import 'package:busgo/services/session.dart';
import 'package:busgo/services/ticket_pdf.dart';
import 'package:busgo/utils/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_data.dart';

Booking _booking({required String status, required DateTime departure, bool upcoming = true}) => Booking(
      bookingId: 3,
      bookingReference: 'BGNOTIFY01',
      status: status,
      upcoming: upcoming,
      tripId: 1,
      operatorName: 'SkyLine Travels',
      busType: BusType.acSeater,
      source: 'Kurnool',
      destination: 'Hyderabad',
      departureTime: departure,
      arrivalTime: departure.add(const Duration(hours: 4)),
      boardingPoint: 'Kurnool Bus Stand',
      droppingPoint: 'MGBS',
      totalAmount: 1000,
      refundAmount: status == 'CANCELLED' ? 900 : null,
      paymentMethod: 'WALLET_DEMO',
      contactPhone: '9876543210',
      contactEmail: 'a@b.com',
      bookedAt: departure.subtract(const Duration(days: 2)),
      cancelledAt: status == 'CANCELLED' ? departure.subtract(const Duration(days: 1)) : null,
      passengers: const [BookingPassenger(seatNumber: '3B', name: 'Asha Rao', age: 30, gender: 'FEMALE')],
    );

Widget _app(Widget home) => MaterialApp(theme: AppTheme.light, home: home);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('notifications', () {
    final now = DateTime(2030, 1, 10, 12, 0);

    test('a confirmed trip departing within 24 hours produces a reminder', () {
      final list = AppNotification.fromBookings(
          [_booking(status: 'CONFIRMED', departure: now.add(const Duration(hours: 5)))], now);
      expect(list.map((n) => n.kind), containsAll([NotificationKind.confirmed, NotificationKind.reminder]));
    });

    test('a cancelled booking produces a cancellation notice with no reminder', () {
      final list = AppNotification.fromBookings(
          [_booking(status: 'CANCELLED', departure: now.add(const Duration(hours: 5)), upcoming: false)], now);
      expect(list.map((n) => n.kind), containsAll([NotificationKind.confirmed, NotificationKind.cancelled]));
      expect(list.any((n) => n.kind == NotificationKind.reminder), isFalse);
    });

    test('a far-away trip has no reminder', () {
      final list = AppNotification.fromBookings(
          [_booking(status: 'CONFIRMED', departure: now.add(const Duration(days: 5)))], now);
      expect(list.any((n) => n.kind == NotificationKind.reminder), isFalse);
    });
  });

  test('the ticket PDF is generated', () async {
    final bytes = await TicketPdf.build(_booking(status: 'CONFIRMED', departure: DateTime(2030, 1, 10, 20, 0)));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    expect(bytes.length, greaterThan(1000));
  });

  testWidgets('choosing a default payment method is remembered', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(const PaymentMethodsScreen()));
    expect(session.preferredPayment, PaymentMethod.upi);
    await tester.tap(find.text(PaymentMethod.wallet.label));
    await tester.pumpAndSettle();
    expect(session.preferredPayment, PaymentMethod.wallet);
  });

  testWidgets('saved passengers screen lists passengers from the server', (tester) async {
    api = ApiService(
      baseUrl: 'http://test',
      sessionOverride: Session(),
      client: fakeServer((request) async {
        expect(request.url.path, '/api/users/me/passengers');
        return jsonResponse([
          {'id': 1, 'name': 'Ravi Kumar', 'age': 25, 'gender': 'MALE'},
          {'id': 2, 'name': 'Sriya', 'age': 23, 'gender': 'FEMALE'},
        ]);
      }),
    );
    await tester.pumpWidget(_app(const SavedPassengersScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Ravi Kumar'), findsOneWidget);
    expect(find.text('Sriya'), findsOneWidget);
    expect(find.text('23 yrs, Female'), findsOneWidget);
  });

  testWidgets('forgot password is two steps: email the code, then reset with it', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final calls = <String>[];
    Map<String, dynamic>? resetBody;
    api = ApiService(
      baseUrl: 'http://test',
      sessionOverride: Session(),
      client: fakeServer((request) async {
        calls.add(request.url.path);
        if (request.url.path == '/api/auth/config') return jsonResponse({'googleEnabled': false, 'emailEnabled': true});
        if (request.url.path == '/api/auth/forgot-password') {
          return jsonResponse({'message': 'If that email is registered, we have sent a 6-digit code.'});
        }
        resetBody = jsonDecode(request.body) as Map<String, dynamic>;
        return jsonResponse({'message': 'ok'});
      }),
    );
    await tester.pumpWidget(_app(const ForgotPasswordScreen()));
    await tester.pumpAndSettle();

    // Step 1: validation first, then the code is requested.
    await tester.tap(find.text('Send code'));
    await tester.pump();
    expect(find.text('Email is required'), findsOneWidget);
    expect(calls.contains('/api/auth/forgot-password'), isFalse);

    await tester.enterText(find.byType(TextFormField).first, 'asha@example.com');
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();
    expect(calls.contains('/api/auth/forgot-password'), isTrue);
    expect(find.text('6-digit code'), findsOneWidget);
    expect(find.textContaining('Resend code in'), findsOneWidget, reason: 'resending is rate limited on screen too');

    // Step 2: the code and the new password are validated, then sent together.
    await tester.tap(find.text('Reset Password').last);
    await tester.pump();
    expect(find.text('Enter the 6-digit code'), findsOneWidget);
    expect(resetBody, isNull);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '123456');
    await tester.enterText(fields.at(1), 'NewPassword1');
    await tester.enterText(fields.at(2), 'NewPassword1');
    await tester.tap(find.text('Reset Password').last);
    await tester.pumpAndSettle();
    expect(resetBody, {'email': 'asha@example.com', 'code': '123456', 'newPassword': 'NewPassword1'});
  });

  testWidgets('forgot password warns when the server cannot send email', (tester) async {
    api = ApiService(
      baseUrl: 'http://test',
      sessionOverride: Session(),
      client: fakeServer((request) async => jsonResponse({'googleEnabled': false, 'emailEnabled': false})),
    );
    await tester.pumpWidget(_app(const ForgotPasswordScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('not set up to send email'), findsOneWidget);
  });
}