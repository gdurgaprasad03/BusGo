import 'package:flutter/material.dart';

import '../models/booking.dart';
import '../models/search_params.dart';
import '../services/session.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/info_row.dart';
import '../widgets/primary_button.dart';

/// Screen 14: shown after the backend confirms the booking.
class BookingConfirmationScreen extends StatelessWidget {
  const BookingConfirmationScreen({super.key, required this.booking});

  final Booking booking;

  void _goHome(BuildContext context) =>
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false);

  /// The return leg of a round trip, shown only when this booking is the matching onward leg.
  SearchParams? get _returnLeg {
    final pending = session.pendingReturn;
    if (pending == null) return null;
    final matches = booking.source == pending.destination && booking.destination == pending.source;
    return matches ? pending : null;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // going "back" would return to the payment screen; send the user home instead
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goHome(context);
      },
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              const SizedBox(height: AppSpacing.lg),
              const Icon(Icons.check_circle, size: 84, color: AppColors.success),
              const SizedBox(height: AppSpacing.md),
              const Text('Booking Confirmed!',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('Your tickets have been booked successfully.',
                  textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
              const Text('(Demo booking - payment was simulated)',
                  textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceTint,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    InfoRow(label: 'Booking ID', value: booking.bookingReference, bold: true),
                    InfoRow(label: 'Operator', value: booking.operatorName),
                    InfoRow(label: 'Source', value: booking.source),
                    InfoRow(label: 'Destination', value: booking.destination),
                    InfoRow(label: 'Date', value: Fmt.dmy(booking.departureTime)),
                    InfoRow(label: 'Departure', value: Fmt.time(booking.departureTime)),
                    InfoRow(label: 'Seats', value: booking.seatList),
                    InfoRow(label: 'Total Fare', value: Fmt.money(booking.totalAmount), bold: true),
                  ],
                ),
              ),
              if (_returnLeg != null) ...[
                const SizedBox(height: AppSpacing.md),
                _ReturnTripCard(
                  leg: _returnLeg!,
                  onBook: () {
                    final leg = _returnLeg!;
                    session.pendingReturn = null; // the return search is a normal one-way search
                    Navigator.pushNamed(context, AppRoutes.results, arguments: leg);
                  },
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: 'View Ticket',
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.bookingDetails, arguments: booking.bookingId),
              ),
              const SizedBox(height: 10),
              OutlinedButton(onPressed: () => _goHome(context), child: const Text('Go to Home')),
            ],
          ),
        ),
      ),
    );
  }
}

/// Offers to book the way back after the onward leg of a round trip is confirmed.
class _ReturnTripCard extends StatelessWidget {
  const _ReturnTripCard({required this.leg, required this.onBook});

  final SearchParams leg;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.keyboard_return, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Round trip: book your return', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
            ],
          ),
          const SizedBox(height: 6),
          Text('${leg.source} to ${leg.destination} on ${Fmt.dmy(leg.date)}',
              style: const TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: onBook, child: const Text('Search return buses')),
        ],
      ),
    );
  }
}
