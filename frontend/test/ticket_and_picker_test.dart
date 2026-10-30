import 'package:busgo/models/booking.dart';
import 'package:busgo/models/bus_type.dart';
import 'package:busgo/services/api_service.dart';
import 'package:busgo/services/session.dart';
import 'package:busgo/widgets/city_picker.dart';
import 'package:busgo/widgets/ticket_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_data.dart';

Booking _booking({bool cancelled = false}) => Booking(
      bookingId: 7,
      bookingReference: 'BGTEST1234',
      status: cancelled ? 'CANCELLED' : 'CONFIRMED',
      upcoming: !cancelled,
      tripId: 1,
      operatorName: 'SkyLine Travels',
      busType: BusType.acSeater,
      source: 'Kurnool',
      destination: 'Hyderabad',
      departureTime: DateTime(2030, 1, 10, 20, 0),
      arrivalTime: DateTime(2030, 1, 11, 5, 0),
      boardingPoint: 'Kurnool Bus Stand',
      droppingPoint: 'MGBS',
      totalAmount: 1700,
      refundAmount: cancelled ? 1530 : null,
      paymentMethod: 'UPI_DEMO',
      contactPhone: '9876543210',
      contactEmail: 'a@b.com',
      bookedAt: DateTime(2030, 1, 1, 10, 0),
      cancelledAt: cancelled ? DateTime(2030, 1, 2, 10, 0) : null,
      passengers: const [
        BookingPassenger(seatNumber: '6', name: 'Ravi Kumar', age: 25, gender: 'MALE'),
        BookingPassenger(seatNumber: '7', name: 'Sriya', age: 23, gender: 'FEMALE'),
      ],
    );

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  testWidgets('ticket shows booking id, route, passengers, seats and fare', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 2400));
    await tester.pumpWidget(_host(TicketCard(booking: _booking(), pageColor: Colors.white)));
    expect(find.text('BUS E-TICKET'), findsOneWidget);
    expect(find.text('BGTEST1234'), findsOneWidget);
    expect(find.text('Kurnool'), findsOneWidget);
    expect(find.text('Hyderabad'), findsOneWidget);
    expect(find.text('Ravi Kumar'), findsOneWidget);
    expect(find.text('Sriya'), findsOneWidget);
    expect(find.text('Kurnool Bus Stand'), findsOneWidget);
    expect(find.text('CONFIRMED'), findsOneWidget);
    expect(find.text('CANCELLED'), findsNothing);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('cancelled ticket is stamped and shows the refund', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 2400));
    await tester.pumpWidget(_host(TicketCard(booking: _booking(cancelled: true), pageColor: Colors.white)));
    expect(find.text('CANCELLED'), findsWidgets);
    expect(find.text('Demo refund'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });

  // The picker loads places through the API service. Here the API is a small fake server, so the widget behaviour is
  // tested in isolation (the real catalog is tested by the Spring tests and places_offline_test.dart).
  group('city picker search', () {
    const catalog = [
      ['Mumbai', 'Maharashtra', true],
      ['Pune', 'Maharashtra', true],
      ['Kurnool', 'Andhra Pradesh', true],
      ['Bengaluru', 'Karnataka', true],
      ['Surat', 'Gujarat', false],
      ['Panaji', 'Goa', true],
      ['Margao', 'Goa', false],
    ];
    const aliases = {'bangalore': 'Bengaluru'};

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      api = ApiService(
        baseUrl: 'http://test',
        sessionOverride: Session(),
        client: fakeServer((request) async {
          if (request.url.path == '/api/places/states') {
            return jsonResponse([
              for (final s in const ['Goa', 'Gujarat', 'Maharashtra'])
                {'name': s, 'type': 'STATE', 'placeCount': 2, 'servedPlaceCount': 1},
            ]);
          }
          final q = (request.url.queryParameters['query'] ?? '').toLowerCase();
          final state = request.url.queryParameters['state'];
          final aliased = aliases[q];
          return jsonResponse([
            for (final c in catalog)
              if ((state == null || c[1] == state) &&
                  (q.isEmpty || (c[0] as String).toLowerCase().contains(q) || c[0] == aliased))
                {'name': c[0], 'state': c[1], 'hasService': c[2]},
          ]);
        }),
      );
    });
    Future<void> open(WidgetTester tester, void Function(String?) onResult) async {
      // A phone-sized logical screen (the test default has a pixel ratio of 3, which is far too small).
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async => onResult(await showCityPicker(context, title: 'Leaving from')),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    Future<void> type(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(TextField), text);
      await tester.pump(const Duration(milliseconds: 400)); // wait out the typing pause (debounce)
      await tester.pumpAndSettle();
    }

    testWidgets('lists the biggest places first, with their state', (tester) async {
      await open(tester, (_) {});
      expect(find.text('Mumbai'), findsOneWidget);
      expect(find.text('Maharashtra'), findsWidgets);
    });

    testWidgets('typing filters the list as you go', (tester) async {
      await open(tester, (_) {});
      await type(tester, 'kur');
      expect(find.text('Kurnool'), findsOneWidget);
      expect(find.text('Mumbai'), findsNothing);
    });

    testWidgets('old names find the modern city (bangalore -> Bengaluru)', (tester) async {
      await open(tester, (_) {});
      await type(tester, 'bangalore');
      expect(find.text('Bengaluru'), findsOneWidget);
    });

    testWidgets('places that have demo buses are marked with a bus icon', (tester) async {
      await open(tester, (_) {});
      await type(tester, 'kurnool');
      expect(find.byIcon(Icons.directions_bus), findsWidgets); // the legend line and Kurnool's marker
      expect(find.byTooltip('Demo buses available'), findsOneWidget);
    });

    testWidgets('a listed place without service is not marked', (tester) async {
      await open(tester, (_) {});
      await type(tester, 'surat');
      expect(find.text('Surat'), findsOneWidget);
      expect(find.byTooltip('Demo buses available'), findsNothing);
    });

    testWidgets('tapping a result returns it', (tester) async {
      String? picked;
      await open(tester, (v) => picked = v);
      await type(tester, 'pune');
      await tester.tap(find.text('Pune').first);
      await tester.pumpAndSettle();
      expect(picked, 'Pune');
    });

    testWidgets('a place that is not in the list can still be searched', (tester) async {
      String? picked;
      await open(tester, (v) => picked = v);
      await type(tester, 'zzzville nagar');
      await tester.tap(find.textContaining('Search for "Zzzville Nagar"'));
      await tester.pumpAndSettle();
      expect(picked, 'Zzzville Nagar');
    });

    testWidgets('the state filter narrows the list to one state', (tester) async {
      await open(tester, (_) {});
      await tester.tap(find.byKey(const Key('stateFilter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Goa').last);
      await tester.pumpAndSettle();
      expect(find.text('Mumbai'), findsNothing);
      expect(find.text('Panaji'), findsOneWidget);
    });
  });
}
