import 'package:flutter/material.dart';

import '../models/trip.dart';
import '../services/api_exception.dart';
import '../services/api_service.dart';
import '../utils/app_config.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/demo_banner.dart';
import '../widgets/info_row.dart';
import '../widgets/primary_button.dart';
import '../widgets/state_views.dart';

/// Screen 10: details of one trip, including boarding and dropping points.
class BusDetailsScreen extends StatefulWidget {
  const BusDetailsScreen({super.key, required this.tripId});

  final int tripId;

  @override
  State<BusDetailsScreen> createState() => _BusDetailsScreenState();
}

class _BusDetailsScreenState extends State<BusDetailsScreen> {
  late Future<Trip> _future = api.getTrip(widget.tripId);

  void _reload() {
    setState(() {
      _future = api.getTrip(widget.tripId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const BackButton(), title: const Text('Bus Details')),
      body: FutureBuilder<Trip>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const LoadingView();
          if (snapshot.hasError) {
            final e = snapshot.error;
            return ErrorView(
              message: e is ApiException ? e.message : 'Could not load this bus.',
              onRetry: _reload,
            );
          }
          final trip = snapshot.data!;
          return Column(
            children: [
              Expanded(child: _Content(trip: trip)),
              SafeArea(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(Fmt.money(trip.fare),
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                          const Text('per seat', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: PrimaryButton(
                          label: trip.availableSeats == 0 ? 'Sold out' : 'Select Seats',
                          onPressed: trip.availableSeats == 0
                              ? null
                              : () => Navigator.pushNamed(context, AppRoutes.seats, arguments: trip),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final ac = trip.busType.isAc;
    final sleeper = trip.busType.isSleeper;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // The demo has no bus photos, so a neutral illustration stands in for the picture.
        Container(
          height: 150,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [Color(0xFFE8F0FF), Color(0xFFD3E3FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Center(child: Icon(Icons.directions_bus_filled, size: 88, color: AppColors.primary)),
        ),
        const SizedBox(height: 14),
        Text(trip.operatorName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.star, color: AppColors.star, size: 18),
            Text(' ${trip.operatorRating.toStringAsFixed(1)}',
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.star)),
            const Text('  (demo rating)', style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _Amenity(icon: sleeper ? Icons.single_bed_outlined : Icons.airline_seat_recline_normal, label: trip.busType.label),
            _Amenity(icon: Icons.bolt, label: 'Charging Point', shown: ac),
            _Amenity(icon: Icons.water_drop_outlined, label: 'Water Bottle', shown: ac),
            _Amenity(icon: Icons.bed_outlined, label: 'Blanket', shown: ac && sleeper),
          ],
        ),
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text('Amenities are sample demo data.', style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _Stop(label: 'Departure', time: Fmt.time(trip.departureTime), place: trip.source)),
                    Expanded(
                      child: _Stop(
                        label: 'Arrival',
                        time: Fmt.time(trip.arrivalTime),
                        place: trip.destination,
                        alignEnd: true,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    const Text('Duration', style: TextStyle(color: AppColors.textMuted)),
                    const Spacer(),
                    Text(Fmt.duration(trip.durationMinutes), style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 6),
                    const Icon(Icons.timer_outlined, size: 18, color: AppColors.textMuted),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Boarding & dropping'),
                InfoRow(label: 'Boarding point', value: trip.boardingPoint),
                InfoRow(label: 'Dropping point', value: trip.droppingPoint),
                InfoRow(label: 'Date', value: Fmt.date(trip.departureTime)),
                InfoRow(label: 'Seats left', value: '${trip.availableSeats} of ${trip.totalSeats}'),
                InfoRow(label: 'Max per booking', value: '${AppConfig.maxSeatsPerBooking} seats'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle('Cancellation policy (demo)'),
                Text('24 hours or more before departure: 90% refund'),
                SizedBox(height: 4),
                Text('6 to 24 hours before departure: 50% refund'),
                SizedBox(height: 4),
                Text('Less than 6 hours before departure: no refund'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const DemoBanner(text: AppConfig.demoNotice),
      ],
    );
  }
}

class _Amenity extends StatelessWidget {
  const _Amenity({required this.icon, required this.label, this.shown = true});

  final IconData icon;
  final String label;
  final bool shown;

  @override
  Widget build(BuildContext context) {
    if (!shown) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceTint,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 64,
            child: Text(label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
          ),
        ],
      ),
    );
  }
}

class _Stop extends StatelessWidget {
  const _Stop({required this.label, required this.time, required this.place, this.alignEnd = false});

  final String label;
  final String time;
  final String place;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
        const SizedBox(height: 2),
        Text(time, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        Text(place, style: const TextStyle(color: AppColors.textMuted)),
      ],
    );
  }
}
