import 'bus_type.dart';

class Seat {
  final String seatNumber;
  final String deck; // LOWER or UPPER
  final int row;
  final int column;
  final bool isAvailable;

  const Seat({
    required this.seatNumber,
    required this.deck,
    required this.row,
    required this.column,
    required this.isAvailable,
  });

  factory Seat.fromJson(Map<String, dynamic> json) => Seat(
        seatNumber: json['seatNumber'] as String,
        deck: json['deck'] as String,
        row: json['row'] as int,
        column: json['column'] as int,
        isAvailable: json['status'] == 'AVAILABLE',
      );
}

/// Seat map of one trip. The screen draws a grid per deck from row/column and leaves
/// an aisle gap after column [aisleAfterColumn], so any bus configuration can be shown.
class SeatLayout {
  final int tripId;
  final BusType busType;
  final int decks;
  final int rows;
  final int columns;
  final int aisleAfterColumn;
  final int availableSeats;
  final List<Seat> seats;

  const SeatLayout({
    required this.tripId,
    required this.busType,
    required this.decks,
    required this.rows,
    required this.columns,
    required this.aisleAfterColumn,
    required this.availableSeats,
    required this.seats,
  });

  factory SeatLayout.fromJson(Map<String, dynamic> json) => SeatLayout(
        tripId: json['tripId'] as int,
        busType: BusType.fromApi(json['busType'] as String),
        decks: json['decks'] as int,
        rows: json['rows'] as int,
        columns: json['columns'] as int,
        aisleAfterColumn: json['aisleAfterColumn'] as int,
        availableSeats: (json['availableSeats'] as num).toInt(),
        seats: (json['seats'] as List<dynamic>)
            .map((s) => Seat.fromJson(s as Map<String, dynamic>))
            .toList(),
      );

  List<Seat> seatsOnDeck(String deck) => seats.where((s) => s.deck == deck).toList();

  Seat? seatByNumber(String number) {
    for (final s in seats) {
      if (s.seatNumber == number) return s;
    }
    return null;
  }
}
