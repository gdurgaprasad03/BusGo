import 'bus_type.dart';

/// One scheduled bus journey, as returned by /api/trips/search and /api/trips/{id}.
class Trip {
  final int tripId;
  final String operatorName;
  final double operatorRating;
  final BusType busType;
  final String source;
  final String destination;
  final DateTime departureTime;
  final DateTime arrivalTime;
  final int durationMinutes;
  final double fare;
  final int availableSeats;
  final int totalSeats;
  final String boardingPoint;
  final String droppingPoint;

  /// Which provider supplied the trip ("demo"), whether it is sample (DEMO) or real (LIVE) data,
  /// and whether this app can book it.
  final String provider;
  final String dataSource;
  final bool bookable;

  bool get isDemo => dataSource == 'DEMO';

  const Trip({
    required this.tripId,
    required this.operatorName,
    required this.operatorRating,
    required this.busType,
    required this.source,
    required this.destination,
    required this.departureTime,
    required this.arrivalTime,
    required this.durationMinutes,
    required this.fare,
    required this.availableSeats,
    required this.totalSeats,
    required this.boardingPoint,
    required this.droppingPoint,
    this.provider = 'demo',
    this.dataSource = 'DEMO',
    this.bookable = true,
  });

  factory Trip.fromJson(Map<String, dynamic> json) => Trip(
        tripId: json['tripId'] as int,
        operatorName: json['operatorName'] as String,
        operatorRating: (json['operatorRating'] as num).toDouble(),
        busType: BusType.fromApi(json['busType'] as String),
        source: json['source'] as String,
        destination: json['destination'] as String,
        departureTime: DateTime.parse(json['departureTime'] as String),
        arrivalTime: DateTime.parse(json['arrivalTime'] as String),
        durationMinutes: (json['durationMinutes'] as num).toInt(),
        fare: (json['fare'] as num).toDouble(),
        availableSeats: (json['availableSeats'] as num).toInt(),
        totalSeats: (json['totalSeats'] as num).toInt(),
        boardingPoint: json['boardingPoint'] as String,
        droppingPoint: json['droppingPoint'] as String,
        provider: (json['provider'] as String?) ?? 'demo',
        dataSource: (json['dataSource'] as String?) ?? 'DEMO',
        bookable: (json['bookable'] as bool?) ?? true,
      );

  Map<String, dynamic> toJson() => {
        'tripId': tripId,
        'operatorName': operatorName,
        'operatorRating': operatorRating,
        'busType': busType.apiValue,
        'source': source,
        'destination': destination,
        'departureTime': departureTime.toIso8601String(),
        'arrivalTime': arrivalTime.toIso8601String(),
        'durationMinutes': durationMinutes,
        'fare': fare,
        'availableSeats': availableSeats,
        'totalSeats': totalSeats,
        'boardingPoint': boardingPoint,
        'droppingPoint': droppingPoint,
        'provider': provider,
        'dataSource': dataSource,
        'bookable': bookable,
      };
}
