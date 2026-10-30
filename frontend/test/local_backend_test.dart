import 'package:busgo/models/booking_draft.dart';
import 'package:busgo/models/payment_method.dart';
import 'package:busgo/models/trip.dart';
import 'package:busgo/services/api_exception.dart';
import 'package:busgo/services/api_service.dart';
import 'package:busgo/services/local_backend_client.dart';
import 'package:busgo/services/session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late ApiService api;
  late DateTime now;
  final tomorrow = DateTime(2026, 6, 10);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 6, 8, 10, 0);
    api = ApiService(client: LocalBackendClient(clock: () => now), sessionOverride: Session());
  });

  Future<void> signUp([String email = 'asha@example.com']) =>
      api.register(fullName: 'Asha Rao', email: email, phone: '9876543210', password: 'Password123');

  BookingDraft draftFor(Trip trip, List<String> seats) {
    return BookingDraft(trip: trip, seatNumbers: seats)
      ..contactPhone = '9876543210'
      ..contactEmail = 'asha@example.com'
      ..paymentMethod = PaymentMethod.upi
      ..passengers = [
        for (final s in seats) PassengerInput(seatNumber: s, name: 'Pax $s', age: 30, gender: 'FEMALE')
      ];
  }

  test('health answers without any server', () async {
    await api.checkHealth();
  });

  test('register, wrong password rejected, login by email and by mobile', () async {
    await signUp();
    await expectLater(api.login(identifier: 'asha@example.com', password: 'wrongwrong'), throwsA(isA<ApiException>()));
    expect((await api.login(identifier: 'ASHA@example.com', password: 'Password123')).fullName, 'Asha Rao');
    expect((await api.login(identifier: '9876543210', password: 'Password123')).email, 'asha@example.com');
  });

  test('duplicate email gives 409 and bad input is rejected', () async {
    await signUp();
    await expectLater(signUp(), throwsA(predicate((e) => e is ApiException && e.isConflict)));
    await expectLater(
        api.register(fullName: 'A', email: 'bad', phone: '1', password: 'x'), throwsA(isA<ApiException>()));
  });

  test('search lists trips, hides sold-out ones, rejects same source and destination', () async {
    final trips = await api.searchTrips(source: 'Kurnool', destination: 'Hyderabad', date: tomorrow);
    expect(trips, isNotEmpty);
    expect(trips.every((t) => t.availableSeats > 0), isTrue);
    expect(trips.any((t) => t.departureTime.hour == 23 && t.departureTime.minute == 45), isFalse); // sold out
    await expectLater(
        api.searchTrips(source: 'Goa', destination: 'goa', date: tomorrow), throwsA(isA<ApiException>()));
    expect(await api.searchTrips(source: 'Kurnool', destination: 'Agra', date: tomorrow), isEmpty);
  });

  test('booking needs login, reduces seats, rejects double booking, cancel restores seats with refund', () async {
    final trip = (await api.searchTrips(source: 'Kurnool', destination: 'Hyderabad', date: tomorrow)).first;
    await expectLater(api.myBookings(), throwsA(predicate((e) => e is ApiException && e.isUnauthorized)));

    await signUp();
    final layout = await api.getSeats(trip.tripId);
    final free = layout.seats.where((s) => s.isAvailable).map((s) => s.seatNumber).take(2).toList();
    final booking = await api.createBooking(draftFor(trip, free));
    expect(booking.totalAmount, trip.fare * 2);
    expect(booking.status, 'CONFIRMED');
    expect((await api.getTrip(trip.tripId)).availableSeats, trip.availableSeats - 2);

    await expectLater(api.createBooking(draftFor(trip, [free.first])),
        throwsA(predicate((e) => e is ApiException && e.isConflict)));
    expect((await api.myBookings()).single.bookingId, booking.bookingId);

    final cancelled = await api.cancelBooking(booking.bookingId);
    expect(cancelled.isCancelled, isTrue);
    expect(cancelled.refundAmount, booking.totalAmount * 0.9); // departs in more than 24h
    expect((await api.getTrip(trip.tripId)).availableSeats, trip.availableSeats);
    await expectLater(api.cancelBooking(booking.bookingId),
        throwsA(predicate((e) => e is ApiException && e.isConflict)));
  });

  test('another user cannot read my booking (403)', () async {
    final trip = (await api.searchTrips(source: 'Mumbai', destination: 'Pune', date: tomorrow)).first;
    await signUp();
    final seat = (await api.getSeats(trip.tripId)).seats.firstWhere((s) => s.isAvailable).seatNumber;
    final booking = await api.createBooking(draftFor(trip, [seat]));
    await api.register(fullName: 'Other', email: 'other@example.com', phone: '9123456789', password: 'Password123');
    await expectLater(
        api.getBooking(booking.bookingId), throwsA(predicate((e) => e is ApiException && e.statusCode == 403)));
  });

  test('saved passengers, complaints, password reset with a code; data survives an app restart', () async {
    await signUp();
    final p = await api.addSavedPassenger(name: 'Ravi', age: 40, gender: 'MALE');
    await expectLater(api.addSavedPassenger(name: 'ravi', age: 40, gender: 'MALE'),
        throwsA(predicate((e) => e is ApiException && e.isConflict)));
    expect(await api.savedPassengers(), hasLength(1));
    await api.deleteSavedPassenger(p.id);
    expect(await api.savedPassengers(), isEmpty);

    await api.raiseComplaint(subject: 'Late bus', message: 'The bus was very late today');
    expect((await api.myComplaints()).single.reference, startsWith('CMP'));

    // Forgot password: the offline build shows the code on screen because it cannot send email.
    final unknown = await api.forgotPassword('nobody@example.com');
    expect(unknown.offlineCode, isNull, reason: 'no code for an unregistered email');
    expect(unknown.message, isNotEmpty);
    final result = await api.forgotPassword('asha@example.com');
    final code = result.offlineCode!;
    expect(code, matches(RegExp(r'^\d{6}$')));
    final wrong = code == '000000' ? '000001' : '000000';
    await expectLater(api.resetPassword(email: 'asha@example.com', code: wrong, newPassword: 'NewPassword1'),
        throwsA(isA<ApiException>()));
    await api.resetPassword(email: 'asha@example.com', code: code, newPassword: 'NewPassword1');
    await expectLater(api.resetPassword(email: 'asha@example.com', code: code, newPassword: 'Another1234'),
        throwsA(isA<ApiException>()), reason: 'a code works only once');
    // A brand-new client (like restarting the app) reads the same stored data.
    final again = ApiService(client: LocalBackendClient(clock: () => now), sessionOverride: Session());
    expect((await again.login(identifier: 'asha@example.com', password: 'NewPassword1')).fullName, 'Asha Rao');
  });
}
