import 'package:flutter/material.dart';

import '../models/booking_draft.dart';
import '../models/seat_layout.dart';
import '../models/trip.dart';
import '../services/api_exception.dart';
import '../services/api_service.dart';
import '../utils/app_config.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/primary_button.dart';
import '../widgets/seat_widget.dart';
import '../widgets/state_views.dart';

/// Screen 11: visual seat map. The layout and seat status come from the backend.
class SeatSelectionScreen extends StatefulWidget {
  const SeatSelectionScreen({super.key, required this.trip});

  final Trip trip;

  @override
  State<SeatSelectionScreen> createState() => _SeatSelectionScreenState();
}

class _SeatSelectionScreenState extends State<SeatSelectionScreen> {
  late Future<SeatLayout> _future = api.getSeats(widget.trip.tripId);
  final List<String> _selected = [];

  void _reload() => setState(() {
        _selected.clear();
        _future = api.getSeats(widget.trip.tripId);
      });

  void _toggle(Seat seat) {
    setState(() {
      if (_selected.contains(seat.seatNumber)) {
        _selected.remove(seat.seatNumber);
      } else if (_selected.length >= AppConfig.maxSeatsPerBooking) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You can select at most ${AppConfig.maxSeatsPerBooking} seats.')),
        );
      } else {
        _selected.add(seat.seatNumber);
      }
    });
  }

  void _continue() {
    final draft = BookingDraft(trip: widget.trip, seatNumbers: List.of(_selected));
    Navigator.pushNamed(context, AppRoutes.passengers, arguments: draft);
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Column(
          children: [
            const Text('Select Seats', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text('${trip.operatorName}  -  ${trip.busType.label}',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w400)),
          ],
        ),
      ),
      body: FutureBuilder<SeatLayout>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const LoadingView();
          if (snapshot.hasError) {
            final e = snapshot.error;
            return ErrorView(
              message: e is ApiException ? e.message : 'Could not load the seat map.',
              onRetry: _reload,
            );
          }
          final layout = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              const SeatLegend(),
              const SizedBox(height: AppSpacing.md),
              for (final deck in const ['LOWER', 'UPPER'])
                if (layout.seatsOnDeck(deck).isNotEmpty) ...[
                  _DeckGrid(
                    layout: layout,
                    deck: deck,
                    showDeckTitle: layout.decks > 1,
                    selected: _selected,
                    onTap: _toggle,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _selected.isEmpty ? 'Selected Seats: none (tap a green seat)' : 'Selected Seats: ${_selected.join(', ')}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                'Total Fare: ${Fmt.money(trip.fare * _selected.length)}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 10),
              PrimaryButton(
                label: 'Proceed',
                onPressed: _selected.isEmpty ? null : _continue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Draws one deck as a grid. Rows/columns and the aisle position come from the layout,
/// so seater (2+2) and sleeper (1+2) buses use the same widget.
class _DeckGrid extends StatelessWidget {
  const _DeckGrid({
    required this.layout,
    required this.deck,
    required this.showDeckTitle,
    required this.selected,
    required this.onTap,
  });

  final SeatLayout layout;
  final String deck;
  final bool showDeckTitle;
  final List<String> selected;
  final void Function(Seat) onTap;

  @override
  Widget build(BuildContext context) {
    final seats = layout.seatsOnDeck(deck);
    final byPosition = {for (final s in seats) '${s.row}-${s.column}': s};
    final sleeper = layout.busType.isSleeper;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            if (showDeckTitle)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(deck == 'LOWER' ? 'Lower Deck' : 'Upper Deck',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            if (deck == 'LOWER')
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.airline_seat_recline_normal, size: 20, color: AppColors.textMuted),
                      SizedBox(width: 4),
                      Text('Driver', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ),
            for (var row = 1; row <= layout.rows; row++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var col = 1; col <= layout.columns; col++) ...[
                      _cell(byPosition['$row-$col'], sleeper),
                      if (col == layout.aisleAfterColumn) const SizedBox(width: 36) else const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cell(Seat? seat, bool sleeper) {
    if (seat == null) return SizedBox(width: sleeper ? 46 : 42, height: sleeper ? 74 : 42);
    final state = !seat.isAvailable
        ? SeatState.booked
        : (selected.contains(seat.seatNumber) ? SeatState.selected : SeatState.available);
    return SeatWidget(
      label: seat.seatNumber,
      state: state,
      sleeper: sleeper,
      onTap: () => onTap(seat),
    );
  }
}
