import 'package:busgo/services/api_exception.dart';
import 'package:busgo/services/api_service.dart';
import 'package:busgo/services/local_backend_client.dart';
import 'package:busgo/services/session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The offline stand-in backend must answer exactly like the Spring backend for places and routes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); // lets the app load its data files in plain tests
  final now = DateTime(2030, 1, 10, 8, 0);
  const tomorrow = '2030-01-11';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api = ApiService(client: LocalBackendClient(clock: () => now), sessionOverride: Session());
  });

  test('autocomplete matches prefixes, old names and respects the state filter', () async {
    expect((await api.searchPlaces('kur')).map((p) => p.name), contains('Kurnool'));
    expect((await api.searchPlaces('bangalore')).first.name, 'Bengaluru');
    expect((await api.searchPlaces('vizag')).first.name, 'Visakhapatnam');
    expect((await api.searchPlaces('goa')).first.name, 'Panaji');
    expect(await api.searchPlaces('zzzzqqqq'), isEmpty);

    final telangana = await api.searchPlaces('', state: 'Telangana', limit: 100);
    expect(telangana.length, greaterThan(20));
    expect(telangana.every((p) => p.state == 'Telangana'), isTrue);

    expect(() => api.searchPlaces('', state: 'Atlantis'), throwsA(isA<ApiException>()));
  });

  test('every state and union territory is in the catalog; only the islands have no demo buses', () async {
    final states = await api.states();
    expect(states.length, 36);
    expect(states.where((s) => s.type == 'UNION_TERRITORY').length, 8);
    expect(states.every((s) => s.placeCount > 0), isTrue);

    final withoutService = states.where((s) => s.servedPlaceCount == 0).map((s) => s.name).toSet();
    expect(withoutService, {'Andaman and Nicobar', 'Lakshadweep'});
  });

  test('listing a place does not imply service: Nashik is listed, Kurnool has buses', () async {
    final nashik = (await api.searchPlaces('nashik')).first;
    expect(nashik.state, 'Maharashtra');
    expect(nashik.hasService, isFalse);
    expect((await api.searchPlaces('kurnool')).first.hasService, isTrue);
  });

  test('routes outside the original corridors exist (generated from the shared route file)', () async {
    // Northeast India, Himalayas, Kerala... all reachable through the generated routes.
    for (final pair in const [
      ['Agartala', 'Shillong'],
      ['Chandigarh', 'Shimla'],
      ['Delhi', 'Dehradun'],
      ['Gangtok', 'Guwahati'],
    ]) {
      final trips = await api.searchTrips(source: pair[0], destination: pair[1], date: DateTime.parse(tomorrow));
      expect(trips, isNotEmpty, reason: '${pair[0]} to ${pair[1]} should have demo trips');
      final back = await api.searchTrips(source: pair[1], destination: pair[0], date: DateTime.parse(tomorrow));
      expect(back, isNotEmpty, reason: '${pair[1]} to ${pair[0]} should have demo trips (both directions)');
    }
  });

  test('search understands alternative names and labels every trip as demo data', () async {
    final trips = await api.searchTrips(source: 'hyderabad', destination: 'BANGALORE', date: DateTime.parse(tomorrow));
    expect(trips, isNotEmpty);
    expect(trips.first.destination, 'Bengaluru');
    for (final t in trips) {
      expect(t.dataSource, 'DEMO');
      expect(t.provider, 'demo');
      expect(t.bookable, isTrue);
    }
  });

  test('trip ids from older app versions (day*1000+index) still open the same trip', () async {
    final epochDay = DateTime.utc(2030, 1, 11).difference(DateTime.utc(1970, 1, 1)).inDays;
    final legacy = await api.getTrip(epochDay * 1000 + 0); // template 0 = Kurnool to Hyderabad, 06:30
    expect(legacy.source, 'Kurnool');
    expect(legacy.destination, 'Hyderabad');
    final current = await api.getTrip(epochDay * 100000 + 0);
    expect(current.source, 'Kurnool');
    expect(current.departureTime, legacy.departureTime);
  });

  test('Google sign-in is reported as unavailable offline', () async {
    expect(await api.googleEnabledOnServer(), isFalse);
    expect(() => api.googleLogin('some-token'), throwsA(isA<ApiException>()));
  });
}
