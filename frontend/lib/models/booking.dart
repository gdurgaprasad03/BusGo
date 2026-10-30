import 'bus_type.dart';

class BookingPassenger {
  final String seatNumber;
  final String name;
  final int age;
  final String gender;

  const BookingPassenger({
    required this.seatNumber,
    required this.name,
    required this.age,
    required this.gender,
  });

  factory BookingPassenger.fromJson(Map<String, dynamic> json) => BookingPassenger(
        seatNumber: json['seatNumber'] as String,
        name: json['name'] as String,
        age: json['age'] as int,
        gender: json['gender'] as String,
      );
}

/// A booking / ticket as returned by the booking endpoints.
class Booking {
  final int bookingId;
  final String bookingReference;
  final String status; // CONFIRMED or CANCELLED
  final bool upcoming;
  final int tripId;
  final String operatorName;
  final BusType busType;
  final String source;
  final String destination;
  final DateTime departureTime;
  final DateTime arrivalTime;
  final String boardingPoint;
  final String droppingPoint;
  final double totalAmount;
  final double? refundAmount;
  final String paymentMethod;
  final String contactPhone;
  final String contactEmail;
  final DateTime bookedAt;
  final DateTime? cancelledAt;
  final List<BookingPassenger> passengers;

  const Booking({
    required this.bookingId,
    required this.bookingReference,
    required this.status,
    required this.upcoming,
    required this.tripId,
    required this.operatorName,
    required this.busType,
    required this.source,
    required this.destination,
    required this.departureTime,
    required this.arrivalTime,
    required this.boardingPoint,
    required this.droppingPoint,
    required this.totalAmount,
    required this.refundAmount,
    required this.paymentMethod,
    required this.contactPhone,
    required this.contactEmail,
    required this.bookedAt,
    required this.cancelledAt,
    required this.passengers,
  });

  bool get isCancelled => status == 'CANCELLED';

  String get seatList => passengers.map((p) => p.seatNumber).join(', ');

  factory Booking.fromJson(Map<String, dynamic> json) => Booking(
        bookingId: json['bookingId'] as int,
        bookingReference: json['bookingReference'] as String,
        status: json['status'] as String,
        upcoming: json['upcoming'] as bool,
        tripId: json['tripId'] as int,
        operatorName: json['operatorName'] as String,
        busType: BusType.fromApi(json['busType'] as String),
        source: json['source'] as String,
        destination: json['destination'] as String,
        departureTime: DateTime.parse(json['departureTime'] as String),
        arrivalTime: DateTime.parse(json['arrivalTime'] as String),
        boardingPoint: json['boardingPoint'] as String,
        droppingPoint: json['droppingPoint'] as String,
        totalAmount: (json['totalAmount'] as num).toDouble(),
        refundAmount: (json['refundAmount'] as num?)?.toDouble(),
        paymentMethod: json['paymentMethod'] as String,
        contactPhone: json['contactPhone'] as String,
        contactEmail: json['contactEmail'] as String,
        bookedAt: DateTime.parse(json['bookedAt'] as String),
        cancelledAt: json['cancelledAt'] == null ? null : DateTime.parse(json['cancelledAt'] as String),
        passengers: (json['passengers'] as List<dynamic>)
            .map((p) => BookingPassenger.fromJson(p as Map<String, dynamic>))
            .toList(),
      );
}
