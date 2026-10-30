import 'package:flutter/material.dart';

import '../models/search_params.dart';
import '../models/trip.dart';
import '../services/api_exception.dart';
import '../services/api_service.dart';
import '../utils/app_config.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/bus_card.dart';
import '../widgets/state_views.dart';

/// Screen 8: buses for the chosen route and date, loaded from the backend.
class SearchResultsScreen extends StatefulWidget {
  const SearchResultsScreen({super.key, required this.params});

  final SearchParams params;

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  late SearchParams _params = widget.params;
  TripFilter _filter = const TripFilter();
  SortOption _sort = SortOption.departure;
  int? _totalFound; // number of buses the server returned for the current route/date
  late Future<List<Trip>> _future = _load();

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  Future<List<Trip>> _load() async {
    final trips = await api.searchTrips(
        source: _params.source, destination: _params.destination, date: _params.date);
    if (mounted) setState(() => _totalFound = trips.length);
    return trips;
  }

  void _reload() {
    setState(() {
      _totalFound = null;
      _future = _load();
    });
  }

  void _changeDay(int delta) {
    final next = _params.date.add(Duration(days: delta));
    final last = _today.add(const Duration(days: AppConfig.searchDaysAhead - 1));
    if (next.isBefore(_today) || next.isAfter(last)) return;
    setState(() {
      _params = _params.withDate(next);
      _totalFound = null;
      _future = _load();
    });
  }

  Future<void> _openFilters() async {
    final result = await Navigator.pushNamed(context, AppRoutes.filters, arguments: _filter);
    if (result is TripFilter) setState(() => _filter = result);
  }

  Future<void> _openSort() async {
    final result = await showModalBottomSheet<SortOption>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: RadioGroup<SortOption>(
          groupValue: _sort,
          onChanged: (v) => Navigator.pop(ctx, v),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Sort by', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
              ),
              for (final option in SortOption.values)
                RadioListTile<SortOption>(value: option, title: Text(option.label)),
            ],
          ),
        ),
      ),
    );
    if (result != null) setState(() => _sort = result);
  }

  /// Filtering and sorting happen on the device; the list itself always comes from the backend.
  List<Trip> _apply(List<Trip> trips) {
    final list = trips.where((t) {
      final typeOk = _filter.busTypes.isEmpty || _filter.busTypes.contains(t.busType);
      final slotOk = _filter.slots.isEmpty || _filter.slots.any((s) => s.contains(t.departureTime));
      // The price slider only restricts results once the user has actually narrowed it.
      final priceOk = !_filter.priceActive || (t.fare >= _filter.minPrice && t.fare <= _filter.maxPrice);
      return typeOk && slotOk && priceOk;
    }).toList();
    switch (_sort) {
      case SortOption.departure:
        list.sort((a, b) => a.departureTime.compareTo(b.departureTime));
      case SortOption.priceLow:
        list.sort((a, b) => a.fare.compareTo(b.fare));
      case SortOption.duration:
        list.sort((a, b) => a.durationMinutes.compareTo(b.durationMinutes));
      case SortOption.rating:
        list.sort((a, b) => b.operatorRating.compareTo(a.operatorRating));
      case SortOption.seats:
        list.sort((a, b) => b.availableSeats.compareTo(a.availableSeats));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final canGoBack = _params.date.isAfter(_today);
    final canGoForward =
        _params.date.isBefore(_today.add(const Duration(days: AppConfig.searchDaysAhead - 1)));
    final count = _totalFound == null ? '' : ' | $_totalFound Bus${_totalFound == 1 ? '' : 'es'}';

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Column(
          children: [
            Text('${_params.source} → ${_params.destination}',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            Text('${Fmt.dmy(_params.date)}$count',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w400)),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openSort,
                    icon: const Icon(Icons.swap_vert, size: 20),
                    label: const Text('Sort'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(42)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openFilters,
                    icon: Badge(
                      isLabelVisible: _filter.isActive,
                      label: Text('${_filter.activeCount}'),
                      child: const Icon(Icons.filter_alt_outlined, size: 20),
                    ),
                    label: const Text('Filters'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(42)),
                  ),
                ),
                IconButton(
                  tooltip: 'Previous day',
                  onPressed: canGoBack ? () => _changeDay(-1) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  tooltip: 'Next day',
                  onPressed: canGoForward ? () => _changeDay(1) : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Trip>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const LoadingView(message: 'Finding buses...');
                }
                if (snapshot.hasError) {
                  final e = snapshot.error;
                  return ErrorView(
                    message: e is ApiException ? e.message : 'Could not load buses. Please try again.',
                    onRetry: _reload,
                  );
                }
                final all = snapshot.data!;
                if (all.isEmpty) {
                  return EmptyView(
                    icon: Icons.directions_bus_outlined,
                    title: 'No buses available',
                    message:
                        'No buses with free seats from ${_params.source} to ${_params.destination} on this date. '
                        'Try another day. The demo covers selected routes only: pick places marked with a bus icon in the '
                        'From/To list, because many places are listed without any service.',
                    actionLabel: 'Try next day',
                    onAction: canGoForward ? () => _changeDay(1) : null,
                  );
                }
                final shown = _apply(all);
                if (shown.isEmpty) {
                  return EmptyView(
                    icon: Icons.filter_alt_off_outlined,
                    title: 'No buses match your filters',
                    message: '${all.length} bus(es) are available without filters.',
                    actionLabel: 'Clear filters',
                    onAction: () => setState(() => _filter = const TripFilter()),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: shown.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => BusCard(
                      trip: shown[i],
                      onTap: () => Navigator.pushNamed(context, AppRoutes.busDetails, arguments: shown[i].tripId),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
