import 'package:busgo/models/trip.dart';
import 'package:busgo/utils/formatters.dart';
import 'package:busgo/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_data.dart';

void main() {
  group('Validators', () {
    test('email', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('not-an-email'), isNotNull);
      expect(Validators.email('asha@example.com'), isNull);
    });

    test('phone must be exactly 10 digits', () {
      expect(Validators.phone('12345'), isNotNull);
      expect(Validators.phone('98765432101'), isNotNull);
      expect(Validators.phone('9876543210'), isNull);
    });

    test('password needs at least 8 characters', () {
      expect(Validators.password('short'), isNotNull);
      expect(Validators.password('longenough1'), isNull);
    });

    test('age must be 1 to 120', () {
      expect(Validators.age('0'), isNotNull);
      expect(Validators.age('121'), isNotNull);
      expect(Validators.age('abc'), isNotNull);
      expect(Validators.age('34'), isNull);
    });
  });

  group('Formatters', () {
    test('duration', () {
      expect(Fmt.duration(270), '4h 30m');
      expect(Fmt.duration(60), '1h');
      expect(Fmt.duration(45), '45m');
    });

    test('initials', () {
      expect(Fmt.initials('Asha Rao'), 'AR');
      expect(Fmt.initials('Madonna'), 'M');
    });
  });

  test('Trip.fromJson reads the backend response shape', () {
    final trip = Trip.fromJson(tripJson(fare: 899, seats: 3));
    expect(trip.operatorName, 'SkyLine Travels');
    expect(trip.fare, 899);
    expect(trip.availableSeats, 3);
    expect(trip.departureTime.hour, 6);
  });
}
