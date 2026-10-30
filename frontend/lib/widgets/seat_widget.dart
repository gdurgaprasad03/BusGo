import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

enum SeatState { available, selected, booked }

/// One seat or sleeper berth. Booked seats are greyed out and cannot be tapped.
class SeatWidget extends StatelessWidget {
  const SeatWidget({
    super.key,
    required this.label,
    required this.state,
    required this.onTap,
    this.sleeper = false,
  });

  final String label;
  final SeatState state;
  final VoidCallback onTap;
  final bool sleeper;

  Color get _color => switch (state) {
        SeatState.available => AppColors.seatAvailable,
        SeatState.selected => AppColors.seatSelected,
        SeatState.booked => AppColors.seatBooked,
      };

  @override
  Widget build(BuildContext context) {
    final booked = state == SeatState.booked;
    final stateText = switch (state) {
      SeatState.available => 'available',
      SeatState.selected => 'selected',
      SeatState.booked => 'booked',
    };
    return Semantics(
      button: !booked,
      label: 'Seat $label, $stateText',
      child: GestureDetector(
        // Booked seats get no tap handler at all, so they can never be selected.
        onTap: booked ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: sleeper ? 46 : 42,
          height: sleeper ? 74 : 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: state == SeatState.available ? _color.withValues(alpha: 0.14) : _color,
            border: Border.all(color: _color, width: 2),
            borderRadius: BorderRadius.circular(sleeper ? 10 : 8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: state == SeatState.available
                  ? _color
                  : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// Green / Blue / Grey legend shown above the seat map.
class SeatLegend extends StatelessWidget {
  const SeatLegend({super.key});

  @override
  Widget build(BuildContext context) {
    Widget item(Color color, String text, {bool filled = true}) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: filled ? color : color.withValues(alpha: 0.14),
                border: Border.all(color: color, width: 2),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            const SizedBox(width: 6),
            Text(text, style: const TextStyle(fontSize: 13)),
          ],
        );

    return Wrap(
      spacing: 18,
      runSpacing: 6,
      children: [
        item(AppColors.seatAvailable, 'Available', filled: false),
        item(AppColors.seatSelected, 'Selected'),
        item(AppColors.seatBooked, 'Booked'),
      ],
    );
  }
}
