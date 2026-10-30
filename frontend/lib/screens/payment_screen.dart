import 'package:flutter/material.dart';

import '../models/booking_draft.dart';
import '../models/payment_method.dart';
import '../services/api_exception.dart';
import '../services/api_service.dart';
import '../services/session.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/demo_banner.dart';
import '../widgets/primary_button.dart';

/// Screen 13: SIMULATED payment. Nothing real is charged and no payment details are collected.
/// The booking is only confirmed when the backend's booking workflow accepts it.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, required this.draft});

  final BookingDraft draft;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _paying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Start with the default method chosen under Profile > Payment Methods.
    widget.draft.paymentMethod = session.preferredPayment;
  }

  Future<void> _pay() async {
    setState(() {
      _paying = true;
      _error = null;
    });
    try {
      final booking = await api.createBooking(widget.draft);
      if (!mounted) return;
      // Keep Home at the bottom of the stack, drop the booking screens above it.
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.confirmation,
        ModalRoute.withName(AppRoutes.home),
        arguments: booking,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isConflict) {
        await _showSeatsTaken(e.message);
      } else {
        setState(() => _error = e.message);
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  /// Someone else booked a seat first: send the user back to a fresh seat map.
  Future<void> _showSeatsTaken(String message) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.event_seat, color: AppColors.warning, size: 36),
        title: const Text('Seats no longer available'),
        content: Text('$message\n\nNo money was charged. Please choose your seats again.'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(minimumSize: const Size(140, 44)),
            child: const Text('Choose seats'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    Navigator.popUntil(context, ModalRoute.withName(AppRoutes.busDetails));
    Navigator.pushNamed(context, AppRoutes.seats, arguments: widget.draft.trip);
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final seatCount = draft.seatNumbers.length;
    return Scaffold(
      appBar: AppBar(leading: const BackButton(), title: const Text('Payment')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const DemoBanner(
            icon: Icons.science_outlined,
            text: 'SIMULATED PAYMENT. No real money is charged, and no card, UPI or bank details '
                'are collected. A real payment provider would be required in production.',
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceTint,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total Amount', style: TextStyle(color: AppColors.textMuted)),
                const SizedBox(height: 4),
                Text(Fmt.money(draft.estimatedTotal),
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                Text('($seatCount Seat${seatCount == 1 ? '' : 's'}: ${draft.seatNumbers.join(', ')})',
                    style: const TextStyle(color: AppColors.textMuted)),
                const SizedBox(height: 4),
                const Text('The final amount is calculated by the server when you pay.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text('Select Payment Method', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          RadioGroup<PaymentMethod>(
            groupValue: draft.paymentMethod,
            onChanged: (m) {
              if (m != null && !_paying) setState(() => draft.paymentMethod = m);
            },
            child: Column(
              children: [
                for (final method in PaymentMethod.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: RadioListTile<PaymentMethod>(
                        value: method,
                        controlAffinity: ListTileControlAffinity.trailing,
                        secondary: Icon(method.icon, color: AppColors.primary),
                        title: Text(method.label, style: const TextStyle(fontSize: 14.5)),
                        subtitle: const Text('Demo only', style: TextStyle(fontSize: 11.5)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_error != null) ...[const SizedBox(height: AppSpacing.sm), ErrorBox(_error!)],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: PrimaryButton(
            label: 'Pay ${Fmt.money(draft.estimatedTotal)}',
            loading: _paying,
            onPressed: _pay,
          ),
        ),
      ),
    );
  }
}
