import 'payment_method.dart';
import 'trip.dart';

class PassengerInput {
  final String seatNumber;
  final String name;
  final int age;
  final String gender; // MALE, FEMALE or OTHER

  const PassengerInput({
    required this.seatNumber,
    required this.name,
    required this.age,
    required this.gender,
  });

  Map<String, dynamic> toJson() =>
      {'seatNumber': seatNumber, 'name': name, 'age': age, 'gender': gender};
}

/// Everything collected on the way to payment. It is passed from screen to screen and finally
/// sent to POST /api/bookings. Note there is no price: the server calculates it.
class BookingDraft {
  final Trip trip;
  final List<String> seatNumbers;
  List<PassengerInput> passengers = [];
  String contactPhone = '';
  String contactEmail = '';
  PaymentMethod paymentMethod = PaymentMethod.upi;

  BookingDraft({required this.trip, required this.seatNumbers});

  /// Preview only. The confirmed amount always comes back from the backend.
  double get estimatedTotal => trip.fare * seatNumbers.length;

  Map<String, dynamic> toJson() => {
        'tripId': trip.tripId,
        'passengers': passengers.map((p) => p.toJson()).toList(),
        'contactPhone': contactPhone,
        'contactEmail': contactEmail,
        'paymentMethod': paymentMethod.apiValue,
      };
}
