import 'bus_type.dart';
import '../utils/app_config.dart';

/// What the user typed on the home screen.
class SearchParams {
  final String source;
  final String destination;
  final DateTime date;

  const SearchParams({required this.source, required this.destination, required this.date});

  SearchParams withDate(DateTime newDate) =>
      SearchParams(source: source, destination: destination, date: newDate);
}

enum SortOption {
  departure('Earliest departure'),
  priceLow('Lowest price'),
  duration('Shortest duration'),
  rating('Highest rating'),
  seats('Most seats available');

  const SortOption(this.label);
  final String label;
}

/// Departure windows offered on the filters screen.
enum DepartureSlot {
  morning('Morning', '6AM - 12PM', 6, 12),
  afternoon('Afternoon', '12PM - 6PM', 12, 18),
  evening('Evening', '6PM - 12AM', 18, 24),
  night('Night', '12AM - 6AM', 0, 6);

  const DepartureSlot(this.label, this.range, this.fromHour, this.toHour);
  final String label;
  final String range;
  final int fromHour;
  final int toHour;

  bool contains(DateTime t) => t.hour >= fromHour && t.hour < toHour;
}

/// Filters chosen on the filters screen. Empty sets mean "no restriction".
class TripFilter {
  final Set<BusType> busTypes;
  final Set<DepartureSlot> slots;
  final double minPrice;
  final double maxPrice;

  const TripFilter({
    this.busTypes = const {},
    this.slots = const {},
    this.minPrice = AppConfig.priceMin,
    this.maxPrice = AppConfig.priceMax,
  });

  bool get priceActive => minPrice > AppConfig.priceMin || maxPrice < AppConfig.priceMax;

  bool get isActive => busTypes.isNotEmpty || slots.isNotEmpty || priceActive;

  int get activeCount => busTypes.length + slots.length + (priceActive ? 1 : 0);
}
