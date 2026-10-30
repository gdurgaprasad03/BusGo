import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/booking.dart';
import '../services/api_exception.dart';
import '../services/api_service.dart';
import '../services/ticket_pdf.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/state_views.dart';
import '../widgets/ticket_card.dart';

/// Screen 16: the e-ticket for one booking, with cancellation.
class BookingDetailsScreen extends StatefulWidget {
  const BookingDetailsScreen({super.key, required this.bookingId});

  final int bookingId;

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  static const _pageColor = Color(0xFFEEF3FB);

  late Future<Booking> _future = api.getBooking(widget.bookingId);
  bool _cancelling = false;
  bool _downloading = false;

  void _reload() {
    setState(() {
      _future = api.getBooking(widget.bookingId);
    });
  }

  /// Plain-text version of the ticket for the "Copy Ticket Details" action.
  String _ticketText(Booking b) => 'BusGo e-ticket (demo)\n'
      'Booking ID: ${b.bookingReference}\n'
      'Status: ${b.status}\n'
      '${b.operatorName} (${b.busType.label})\n'
      '${b.source} to ${b.destination}\n'
      'Departure: ${Fmt.dateTime(b.departureTime)} from ${b.boardingPoint}\n'
      'Arrival: ${Fmt.dateTime(b.arrivalTime)} at ${b.droppingPoint}\n'
      'Passengers: ${b.passengers.map((p) => '${p.name} (seat ${p.seatNumber})').join(', ')}\n'
      'Total fare: ${Fmt.money(b.totalAmount)}';

  Future<void> _copy(Booking b) async {
    await Clipboard.setData(ClipboardData(text: _ticketText(b)));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ticket details copied')));
    }
  }

  /// Builds the ticket as a PDF and opens the system save / share sheet.
  Future<void> _downloadPdf(Booking b) async {
    setState(() => _downloading = true);
    try {
      await TicketPdf.share(b);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not create the PDF on this device. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _confirmCancel(Booking booking) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this booking?'),
        content: const Text(
          'Demo cancellation policy:\n'
          '- 24 hours or more before departure: 90% refund\n'
          '- 6 to 24 hours before: 50% refund\n'
          '- Less than 6 hours before: no refund\n\n'
          'Your seats will be released. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep booking')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Cancel booking'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      final updated = await api.cancelBooking(booking.bookingId);
      if (!mounted) return;
      setState(() {
        _future = Future.value(updated);
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Booking cancelled. Demo refund: ${Fmt.money(updated.refundAmount ?? 0)}'),
      ));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      _reload(); // the status may have changed on the server; show the real state
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageColor,
      appBar: AppBar(
        backgroundColor: _pageColor,
        surfaceTintColor: _pageColor,
        leading: const BackButton(),
        title: const Text('Booking Details'),
      ),
      body: FutureBuilder<Booking>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const LoadingView();
          if (snapshot.hasError) {
            final e = snapshot.error;
            return ErrorView(
              message: e is ApiException ? e.message : 'Could not load this booking.',
              onRetry: _reload,
            );
          }
          final b = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
            children: [
              TicketCard(booking: b, pageColor: _pageColor),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                onPressed: _downloading ? null : () => _downloadPdf(b),
                icon: _downloading
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.download, size: 20),
                label: const Text('Download Ticket (PDF)'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _copy(b),
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy Ticket Details'),
                style: OutlinedButton.styleFrom(backgroundColor: Colors.white),
              ),
              const SizedBox(height: 10),
              if (b.upcoming)
                OutlinedButton.icon(
                  onPressed: _cancelling ? null : () => _confirmCancel(b),
                  icon: _cancelling
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.cancel_outlined),
                  label: const Text('Cancel Booking'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                    backgroundColor: Colors.white,
                  ),
                ),
              if (!b.upcoming && !b.isCancelled)
                const Center(
                  child: Text('This trip has departed, so it can no longer be cancelled.',
                      style: TextStyle(color: AppColors.textMuted)),
                ),
            ],
          );
        },
      ),
    );
  }
}
