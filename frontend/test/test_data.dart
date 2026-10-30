import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// JSON for one trip in the same shape the Spring Boot API returns.
Map<String, dynamic> tripJson({
  int id = 1,
  String operator = 'SkyLine Travels',
  String busType = 'AC_SEATER',
  int seats = 32,
  double fare = 550,
}) =>
    {
      'tripId': id,
      'operatorName': operator,
      'operatorRating': 4.4,
      'busType': busType,
      'source': 'Kurnool',
      'destination': 'Hyderabad',
      'departureTime': '2030-01-10T06:30:00',
      'arrivalTime': '2030-01-10T11:00:00',
      'durationMinutes': 270,
      'fare': fare,
      'availableSeats': seats,
      'totalSeats': 40,
      'boardingPoint': 'Kurnool Bus Stand',
      'droppingPoint': 'MGBS',
    };

http.Response jsonResponse(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

/// A fake HTTP client: every request is answered by [handler], no network involved.
MockClient fakeServer(Future<http.Response> Function(http.Request request) handler) => MockClient(handler);
