import 'package:flutter/material.dart';

import '../models/bus_type.dart';
import '../models/search_params.dart';
import '../utils/app_config.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/primary_button.dart';

/// Screen 9: bus type, departure time and price range. Returns the chosen TripFilter.
class FiltersScreen extends StatefulWidget {
  const FiltersScreen({super.key, required this.initial});

  final TripFilter initial;

  @override
  State<FiltersScreen> createState() => _FiltersScreenState();
}

class _FiltersScreenState extends State<FiltersScreen> {
  late final Set<BusType> _types = {...widget.initial.busTypes};
  late final Set<DepartureSlot> _slots = {...widget.initial.slots};
  late RangeValues _price = RangeValues(widget.initial.minPrice, widget.initial.maxPrice);

  void _toggle<T>(Set<T> set, T value, bool? on) =>
      setState(() => on == true ? set.add(value) : set.remove(value));

  void _reset() => setState(() {
        _types.clear();
        _slots.clear();
        _price = const RangeValues(AppConfig.priceMin, AppConfig.priceMax);
      });

  Widget _heading(String text) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 4),
        child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Filters'),
        actions: [
          TextButton(onPressed: _reset, child: const Text('Reset', style: TextStyle(fontSize: 15))),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _heading('Bus Type'),
          for (final type in BusType.values)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              value: _types.contains(type),
              title: Text(type.label.replaceFirst('Non-AC', 'Non AC').replaceFirst('AC ', 'AC ')),
              onChanged: (on) => _toggle(_types, type, on),
            ),
          _heading('Departure Time'),
          for (final slot in DepartureSlot.values)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              value: _slots.contains(slot),
              title: Text('${slot.label} (${slot.range})'),
              onChanged: (on) => _toggle(_slots, slot, on),
            ),
          _heading('Price Range'),
          Text('${Fmt.money(_price.start)} - ${Fmt.money(_price.end)}',
              style: const TextStyle(color: AppColors.textMuted)),
          RangeSlider(
            values: _price,
            min: AppConfig.priceMin,
            max: AppConfig.priceMax,
            divisions: ((AppConfig.priceMax - AppConfig.priceMin) / 50).round(),
            labels: RangeLabels(Fmt.money(_price.start), Fmt.money(_price.end)),
            onChanged: (v) => setState(() => _price = v),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: PrimaryButton(
            label: 'Apply Filters',
            onPressed: () => Navigator.pop(
              context,
              TripFilter(
                busTypes: {..._types},
                slots: {..._slots},
                minPrice: _price.start,
                maxPrice: _price.end,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
