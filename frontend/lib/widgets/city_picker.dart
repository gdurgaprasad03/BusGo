import 'dart:async';

import 'package:flutter/material.dart';

import '../models/place.dart';
import '../services/api_exception.dart';
import '../services/api_service.dart';
import '../utils/app_theme.dart';

/// Bottom sheet with a search box for choosing a place anywhere in India (about 6,200 cities and towns).
/// Type to filter, or narrow the list to one state or union territory. Places that have demo buses are marked.
/// IMPORTANT: a place being listed does NOT mean buses run there. Returns the chosen place name, or null.
Future<String?> showCityPicker(BuildContext context, {required String title, String? exclude}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => _CityPickerSheet(title: title, exclude: exclude),
  );
}

class _CityPickerSheet extends StatefulWidget {
  const _CityPickerSheet({required this.title, this.exclude});

  final String title;
  final String? exclude;

  @override
  State<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<_CityPickerSheet> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  String? _state; // null = all states and union territories
  List<StateInfo> _states = const [];

  List<Place> _places = const [];
  bool _loading = true;
  String? _error;
  int _requestId = 0; // ignores answers that arrive after a newer search was started

  @override
  void initState() {
    super.initState();
    _load();
    _loadStates();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadStates() async {
    try {
      final states = await api.states();
      if (mounted) setState(() => _states = states);
    } on ApiException {
      // The state filter is optional; the search box still works without it.
    }
  }

  Future<void> _load() async {
    final id = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final places = await api.searchPlaces(_query, state: _state);
      if (!mounted || id != _requestId) return;
      setState(() {
        _places = places.where((p) => p.name != widget.exclude).toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _onChanged(String value) {
    _query = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _load); // wait until typing pauses
  }

  String _titleCase(String text) => text
      .trim()
      .split(RegExp(r'\s+'))
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');

  @override
  Widget build(BuildContext context) {
    final typed = _query.trim();
    final exact = _places.any((p) => p.name.toLowerCase() == typed.toLowerCase());
    final showCustom = typed.isNotEmpty && !_loading && _error == null && !exact && _places.isEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onChanged: _onChanged,
                  onSubmitted: (_) {
                    if (_places.length == 1) Navigator.pop(context, _places.first.name);
                  },
                  decoration: InputDecoration(
                    hintText: 'Search any city or town in India',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _controller.clear();
                              _query = '';
                              _load();
                            },
                          ),
                  ),
                ),
              ),
              if (_states.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: DropdownButtonFormField<String?>(
                    key: const Key('stateFilter'),
                    initialValue: _state,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'State / union territory',
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('All states and union territories')),
                      for (final s in _states)
                        DropdownMenuItem<String?>(
                          value: s.name,
                          child: Text('${s.name}${s.type == 'UNION_TERRITORY' ? ' (UT)' : ''}',
                              overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) {
                      setState(() => _state = v);
                      _load();
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                child: Row(
                  children: [
                    const Icon(Icons.directions_bus, size: 14, color: AppColors.success),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Places with a bus icon have demo buses. Others are listed but have no services.',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(child: _body(typed, showCustom)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(String typed, bool showCustom) {
    if (_loading && _places.isEmpty) {
      return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    return ListView(
      shrinkWrap: true,
      children: [
        for (final place in _places)
          ListTile(
            leading: Icon(Icons.location_city, color: place.hasService ? AppColors.primary : AppColors.textMuted),
            title: Text(place.name),
            subtitle: Text(place.state),
            trailing: place.hasService
                ? const Tooltip(
                    message: 'Demo buses available',
                    child: Icon(Icons.directions_bus, color: AppColors.success, size: 20),
                  )
                : null,
            onTap: () => Navigator.pop(context, place.name),
          ),
        if (showCustom)
          ListTile(
            leading: const Icon(Icons.travel_explore, color: AppColors.textMuted),
            title: Text('Search for "${_titleCase(typed)}"'),
            subtitle: const Text('Not in the list. No buses are expected for this place'),
            onTap: () => Navigator.pop(context, _titleCase(typed)),
          ),
        if (_places.isEmpty && !showCustom && !_loading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('No matching place', style: TextStyle(color: AppColors.textMuted))),
          ),
      ],
    );
  }
}
