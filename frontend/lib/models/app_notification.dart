import 'booking.dart';

enum NotificationKind { confirmed, cancelled, reminder }

/// An in-app notification. They are derived from the user's real bookings (there is no push service).
class AppNotification {
  final NotificationKind kind;
  final String title;
  final String message;
  final DateTime time;
  final int bookingId;

  const AppNotification({
    required this.kind,
    required this.title,
    required this.message,
    required this.time,
    required this.bookingId,
  });

  /// Builds notifications, newest first:
  /// - a "Booking confirmed" entry for each confirmed or cancelled booking (when it was made),
  /// - a "Booking cancelled" entry for each cancellation,
  /// - a "Trip reminder" for confirmed trips departing within the next 24 hours.
  static List<AppNotification> fromBookings(List<Booking> bookings, DateTime now) {
    final list = <AppNotification>[];
    for (final b in bookings) {
      list.add(AppNotification(
        kind: NotificationKind.confirmed,
        title: 'Booking confirmed',
        message: '${b.source} to ${b.destination}, seats ${b.seatList}. Booking ID ${b.bookingReference}.',
        time: b.bookedAt,
        bookingId: b.bookingId,
      ));
      if (b.isCancelled && b.cancelledAt != null) {
        list.add(AppNotification(
          kind: NotificationKind.cancelled,
          title: 'Booking cancelled',
          message: 'Booking ${b.bookingReference} was cancelled. Demo refund: '
              '${(b.refundAmount ?? 0).toStringAsFixed(0)} rupees.',
          time: b.cancelledAt!,
          bookingId: b.bookingId,
        ));
      }
      final hoursLeft = b.departureTime.difference(now).inHours;
      if (b.upcoming && hoursLeft >= 0 && hoursLeft < 24) {
        list.add(AppNotification(
          kind: NotificationKind.reminder,
          title: 'Trip reminder',
          message: '${b.source} to ${b.destination} departs soon from ${b.boardingPoint}.',
          time: now,
          bookingId: b.bookingId,
        ));
      }
    }
    list.sort((a, b) => b.time.compareTo(a.time));
    return list;
  }
}
