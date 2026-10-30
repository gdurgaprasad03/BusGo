import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/booking.dart';
import '../models/payment_method.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';

/// A boarding-pass style e-ticket: header, journey, tear-off line with notches, passenger table,
/// fare, QR code and terms. [pageColor] must be the colour behind the ticket so the notches blend in.
class TicketCard extends StatelessWidget {
  const TicketCard({super.key, required this.booking, required this.pageColor});

  final Booking booking;
  final Color pageColor;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final cancelled = b.isCancelled;
    final (statusText, statusColor) = cancelled
        ? ('CANCELLED', AppColors.danger)
        : b.upcoming
            ? ('CONFIRMED', AppColors.success)
            : ('COMPLETED', AppColors.textMuted);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
            boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 14, offset: Offset(0, 6))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(booking: b, statusText: statusText, statusColor: statusColor),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.operatorName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    Text(b.busType.label, style: const TextStyle(color: AppColors.textMuted)),
                    const SizedBox(height: 14),
                    _Journey(booking: b),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _Point(label: 'BOARDING POINT', value: b.boardingPoint)),
                        const SizedBox(width: 12),
                        Expanded(child: _Point(label: 'DROPPING POINT', value: b.droppingPoint, alignEnd: true)),
                      ],
                    ),
                  ],
                ),
              ),
              _TearLine(pageColor: pageColor),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 8),
                child: _Passengers(booking: b),
              ),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 18), child: Divider(height: 24)),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                child: _Fare(booking: b),
              ),
              _TearLine(pageColor: pageColor),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
                child: _Footer(booking: b),
              ),
            ],
          ),
        ),
        if (cancelled)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Transform.rotate(
                  angle: -0.45,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.danger.withValues(alpha: 0.55), width: 4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'CANCELLED',
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                        color: AppColors.danger.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.booking, required this.statusText, required this.statusColor});

  final Booking booking;
  final String statusText;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.primaryDark, AppColors.primary]),
        borderRadius: BorderRadius.vertical(top: Radius.circular(17)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_bus_filled, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              const Text('BusGo', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              const Spacer(),
              const Flexible(
                child: Text('BUS E-TICKET',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('BOOKING ID / PNR',
                        style: TextStyle(color: Colors.white70, fontSize: 10.5, letterSpacing: 1)),
                    SelectableText(booking.bookingReference,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 2)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                child: Text(statusText,
                    style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Journey extends StatelessWidget {
  const _Journey({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final minutes = b.arrivalTime.difference(b.departureTime).inMinutes;
    final sameDay = b.departureTime.day == b.arrivalTime.day && b.departureTime.month == b.arrivalTime.month;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          flex: 3,
          child: _Stop(place: b.source, time: Fmt.time(b.departureTime), date: Fmt.dmy(b.departureTime)),
        ),
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              children: [
                Text(Fmt.duration(minutes), style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                Row(
                  children: [
                    const Icon(Icons.circle, size: 7, color: AppColors.primary),
                    Expanded(child: Container(height: 1.5, color: AppColors.primary.withValues(alpha: 0.4))),
                    const Icon(Icons.directions_bus, size: 18, color: AppColors.primary),
                    Expanded(child: Container(height: 1.5, color: AppColors.primary.withValues(alpha: 0.4))),
                    const Icon(Icons.circle, size: 7, color: AppColors.primary),
                  ],
                ),
                if (!sameDay)
                  const Text('Arrives next day', style: TextStyle(fontSize: 10.5, color: AppColors.warning)),
              ],
            ),
          ),
        ),
        Flexible(
          flex: 3,
          child: _Stop(
            place: b.destination,
            time: Fmt.time(b.arrivalTime),
            date: Fmt.dmy(b.arrivalTime),
            alignEnd: true,
          ),
        ),
      ],
    );
  }
}

class _Stop extends StatelessWidget {
  const _Stop({required this.place, required this.time, required this.date, this.alignEnd = false});

  final String place;
  final String time;
  final String date;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(place,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        Text(time, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary)),
        Text(date, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
      ],
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.label, required this.value, this.alignEnd = false});

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10.5, letterSpacing: 0.8, color: AppColors.textMuted)),
        const SizedBox(height: 2),
        Text(value, textAlign: alignEnd ? TextAlign.end : TextAlign.start,
            style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _Passengers extends StatelessWidget {
  const _Passengers({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    const head = TextStyle(fontSize: 10.5, letterSpacing: 0.8, color: AppColors.textMuted, fontWeight: FontWeight.w700);
    return Column(
      children: [
        const Row(
          children: [
            Expanded(flex: 5, child: Text('PASSENGER', style: head)),
            Expanded(flex: 3, child: Text('AGE / SEX', style: head)),
            Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: Text('SEAT', style: head))),
          ],
        ),
        const SizedBox(height: 6),
        for (final p in booking.passengers)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(flex: 5, child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700))),
                Expanded(flex: 3, child: Text('${p.age} / ${p.gender[0]}')),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(p.seatNumber,
                          style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Fare extends StatelessWidget {
  const _Fare({required this.booking});

  final Booking booking;

  Widget _line(String label, String value, {bool bold = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Text(label, style: const TextStyle(color: AppColors.textMuted)),
            const Spacer(),
            Text(value,
                style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600, fontSize: bold ? 16 : 14, color: color)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final b = booking;
    return Column(
      children: [
        _line('Payment mode', PaymentMethod.labelFor(b.paymentMethod)),
        _line('Booked on', Fmt.dateTime(b.bookedAt)),
        _line('Contact', b.contactPhone),
        _line('Total fare', Fmt.money(b.totalAmount), bold: true),
        if (b.isCancelled) ...[
          _line('Cancelled on', b.cancelledAt == null ? '-' : Fmt.dateTime(b.cancelledAt!)),
          _line('Demo refund', Fmt.money(b.refundAmount ?? 0), bold: true, color: AppColors.success),
        ],
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // A real QR code that encodes the booking reference.
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: QrImageView(data: booking.bookingReference, size: 120, padding: EdgeInsets.zero),
        ),
        const SizedBox(height: 6),
        Text('Scan to verify: ${booking.bookingReference}',
            style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
        const SizedBox(height: 12),
        const Text(
          'Carry a valid photo ID. Reach the boarding point at least 15 minutes before departure. '
          'Show this ticket (or the Booking ID) to the conductor.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.4),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4E0),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'DEMO TICKET - sample data, simulated payment. Not valid for travel.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B4A00)),
          ),
        ),
      ],
    );
  }
}

/// Dashed tear-off line with half-circle notches on both sides.
class _TearLine extends StatelessWidget {
  const _TearLine({required this.pageColor});

  final Color pageColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final dashes = (constraints.maxWidth / 9).floor();
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(
                      dashes,
                      (_) => Container(width: 5, height: 1.5, color: const Color(0xFFCBD3E1)),
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(left: -12, top: 0, child: _Notch(color: pageColor)),
          Positioned(right: -12, top: 0, child: _Notch(color: pageColor)),
        ],
      ),
    );
  }
}

class _Notch extends StatelessWidget {
  const _Notch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
