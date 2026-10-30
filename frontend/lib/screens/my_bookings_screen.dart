import 'package:flutter/material.dart';

import '../models/booking.dart';
import '../services/api_exception.dart';
import '../services/api_service.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/state_views.dart';

/// Screen 15: bookings split into Upcoming and Past tabs.
class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key, required this.onSearchBuses});

  /// Switches to the Home tab (used by the empty-state button).
  final VoidCallback onSearchBuses;

  @override
  State<MyBookingsScreen> createState() => MyBookingsScreenState();
}

class MyBookingsScreenState extends State<MyBookingsScreen> with SingleTickerProviderStateMixin {
  late Future<List<Booking>> _future = api.myBookings();
  late final TabController _tabs = TabController(length: 2, vsync: this);

  void reload() {
    setState(() {
      _future = api.myBookings();
    });
  }

  Future<void> _open(Booking booking) async {
    await Navigator.pushNamed(context, AppRoutes.bookingDetails, arguments: booking.bookingId);
    if (mounted) reload(); // the booking may have been cancelled on the details screen
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Bookings')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppColors.surfaceTint,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: TabBar(
                controller: _tabs,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.textMuted,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700),
                tabs: const [Tab(text: 'Upcoming', height: 38), Tab(text: 'Past', height: 38)],
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Booking>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) return const LoadingView();
                if (snapshot.hasError) {
                  final e = snapshot.error;
                  return ErrorView(
                    message: e is ApiException ? e.message : 'Could not load your bookings.',
                    onRetry: reload,
                  );
                }
                final all = snapshot.data!;
                final upcoming = all.where((b) => b.upcoming).toList();
                final past = all.where((b) => !b.upcoming).toList();
                return TabBarView(
                  controller: _tabs,
                  children: [
                    _BookingList(
                      bookings: upcoming,
                      onTap: _open,
                      onRefresh: () async => reload(),
                      empty: EmptyView(
                        icon: Icons.confirmation_number_outlined,
                        title: 'No upcoming trips',
                        message: 'Your confirmed bookings will appear here.',
                        actionLabel: 'Search buses',
                        onAction: widget.onSearchBuses,
                      ),
                    ),
                    _BookingList(
                      bookings: past,
                      onTap: _open,
                      onRefresh: () async => reload(),
                      empty: const EmptyView(
                        icon: Icons.history,
                        title: 'No past trips',
                        message: 'Completed and cancelled bookings will appear here.',
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingList extends StatelessWidget {
  const _BookingList({
    required this.bookings,
    required this.onTap,
    required this.onRefresh,
    required this.empty,
  });

  final List<Booking> bookings;
  final void Function(Booking) onTap;
  final Future<void> Function() onRefresh;
  final Widget empty;

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) return empty;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        itemCount: bookings.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _BookingTile(booking: bookings[i], onTap: () => onTap(bookings[i])),
      ),
    );
  }
}

class _BookingTile extends StatelessWidget {
  const _BookingTile({required this.booking, required this.onTap});

  final Booking booking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final (statusText, statusColor) = b.isCancelled
        ? ('Cancelled', AppColors.warning)
        : b.upcoming
            ? ('Confirmed', AppColors.success)
            : ('Completed', AppColors.textMuted);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(b.operatorName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(statusText,
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('${b.source} → ${b.destination}', style: const TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 4),
            Text('${Fmt.dmy(b.departureTime)} | ${Fmt.time(b.departureTime)}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Text('Seats: ${b.seatList}', style: const TextStyle(fontWeight: FontWeight.w600))),
                OutlinedButton(
                  onPressed: onTap,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(110, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  child: Text(b.upcoming ? 'View Ticket' : 'View Details'),
                ),
              ],
            ),
            Text('Ref: ${b.bookingReference}', style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
