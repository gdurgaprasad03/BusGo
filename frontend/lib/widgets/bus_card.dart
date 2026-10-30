import 'package:flutter/material.dart';

import '../models/trip.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';

/// One bus in the search results list.
class BusCard extends StatelessWidget {
  const BusCard({super.key, required this.trip, required this.onTap});

  final Trip trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fewLeft = trip.availableSeats <= 5;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      trip.operatorName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (trip.isDemo) ...[
                    // Every sample trip is labelled so it can never be mistaken for a live one.
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4E0),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('DEMO',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B4A00))),
                    ),
                  ],
                  const Icon(Icons.star, size: 16, color: AppColors.star),
                  const SizedBox(width: 2),
                  Text(trip.operatorRating.toStringAsFixed(1),
                      style: const TextStyle(color: AppColors.star, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(Fmt.time(trip.departureTime),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  Expanded(
                    child: Column(
                      children: [
                        Text(Fmt.duration(trip.durationMinutes),
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        const Divider(indent: 8, endIndent: 8, height: 8),
                      ],
                    ),
                  ),
                  Text(Fmt.time(trip.arrivalTime), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(trip.busType.label, style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
                        const SizedBox(height: 2),
                        Text(
                          '${trip.availableSeats} seats available',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: fewLeft ? AppColors.warning : AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(Fmt.money(trip.fare), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
