import 'package:flutter/material.dart';

import '../models/search_params.dart';
import '../services/session.dart';
import '../utils/app_config.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/city_picker.dart';
import '../widgets/demo_banner.dart';
import '../widgets/primary_button.dart';
import '../widgets/user_avatar.dart';
import 'logout_dialog.dart';

/// Screen 7: choose source, destination and date, then search.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onOpenBookings, this.onOpenProfile});

  final VoidCallback? onOpenBookings;
  final VoidCallback? onOpenProfile;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String? _source = 'Kurnool';
  String? _destination = 'Hyderabad';
  late DateTime _date = _today.add(const Duration(days: 1));
  bool _roundTrip = false;
  late DateTime _returnDate = _today.add(const Duration(days: 3));

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  Future<void> _pickCity({required bool isSource}) async {
    final city = await showCityPicker(
      context,
      title: isSource ? 'Leaving from' : 'Going to',
      exclude: isSource ? _destination : _source,
    );
    if (city == null) return;
    setState(() => isSource ? _source = city : _destination = city);
  }

  void _swap() => setState(() {
        final tmp = _source;
        _source = _destination;
        _destination = tmp;
      });

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: _today,
      lastDate: _today.add(const Duration(days: AppConfig.searchDaysAhead - 1)),
      helpText: 'Travel date (demo trips: next ${AppConfig.searchDaysAhead} days)',
    );
    if (picked == null) return;
    setState(() {
      _date = picked;
      if (_returnDate.isBefore(_date)) _returnDate = _date; // the return can never be before the onward trip
    });
  }

  Future<void> _pickReturnDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _returnDate.isBefore(_date) ? _date : _returnDate,
      firstDate: _date,
      lastDate: _today.add(const Duration(days: AppConfig.searchDaysAhead - 1)),
      helpText: 'Return date',
    );
    if (picked != null) setState(() => _returnDate = picked);
  }

  void _search() {
    if (_source == null || _destination == null) {
      _toast('Please choose both source and destination.');
      return;
    }
    if (_source == _destination) {
      _toast('Source and destination must be different.');
      return;
    }
    // For a round trip, remember the return leg. It is offered after the onward booking is confirmed.
    session.pendingReturn = _roundTrip
        ? SearchParams(source: _destination!, destination: _source!, date: _returnDate)
        : null;
    Navigator.pushNamed(
      context,
      AppRoutes.results,
      arguments: SearchParams(source: _source!, destination: _destination!, date: _date),
    );
  }

  void _toast(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final firstName = (session.user?.fullName ?? '').split(' ').first;

    return Scaffold(
      key: _scaffoldKey,
      drawer: _MenuDrawer(
        onOpenBookings: widget.onOpenBookings,
        onOpenProfile: widget.onOpenProfile,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Menu',
                  icon: const Icon(Icons.menu, size: 28),
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Notifications',
                  icon: const Icon(Icons.notifications_none, size: 28),
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.notifications),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(firstName.isEmpty ? 'Hi there!' : 'Hi, $firstName!',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  const Text('Where do you want to travel?', style: TextStyle(color: AppColors.textMuted)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _TripTypeOption(
                          label: 'One Way',
                          selected: !_roundTrip,
                          onTap: () => setState(() => _roundTrip = false),
                        ),
                        const SizedBox(width: 22),
                        _TripTypeOption(
                          label: 'Round Trip',
                          selected: _roundTrip,
                          onTap: () => setState(() => _roundTrip = true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        Column(
                          children: [
                            _PlaceTile(
                              icon: Icons.location_on,
                              iconColor: AppColors.logoRed,
                              label: 'From',
                              value: _source,
                              onTap: () => _pickCity(isSource: true),
                            ),
                            const SizedBox(height: 10),
                            _PlaceTile(
                              icon: Icons.location_on,
                              iconColor: AppColors.primary,
                              label: 'To',
                              value: _destination,
                              onTap: () => _pickCity(isSource: false),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 14),
                          child: Material(
                            color: Colors.white,
                            shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
                            elevation: 1,
                            child: IconButton(
                              tooltip: 'Swap source and destination',
                              icon: const Icon(Icons.swap_vert, color: AppColors.primary),
                              onPressed: _swap,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _PlaceTile(
                      icon: Icons.calendar_month_outlined,
                      iconColor: AppColors.textMuted,
                      label: Fmt.dmy(_date),
                      value: Fmt.weekday(_date),
                      onTap: _pickDate,
                      labelIsMain: true,
                    ),
                    if (_roundTrip) ...[
                      const SizedBox(height: 10),
                      _PlaceTile(
                        icon: Icons.keyboard_return,
                        iconColor: AppColors.textMuted,
                        label: Fmt.dmy(_returnDate),
                        value: 'Return - ${Fmt.weekday(_returnDate)}',
                        onTap: _pickReturnDate,
                        labelIsMain: true,
                      ),
                    ],
                    const SizedBox(height: 16),
                    PrimaryButton(label: 'Search Buses', onPressed: _search),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('Popular Routes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 78,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: AppConfig.popularRoutes.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final route = AppConfig.popularRoutes[i];
                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      setState(() {
                        _source = route[0];
                        _destination = route[1];
                      });
                      _search();
                    },
                    child: Container(
                      width: 138,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(route[0], style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text('-> ${route[1]}', style: const TextStyle(color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            const DemoBanner(text: AppConfig.demoNotice),
          ],
        ),
      ),
    );
  }
}

class _TripTypeOption extends StatelessWidget {
  const _TripTypeOption({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: selected ? AppColors.primary : AppColors.textMuted, size: 20),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: selected ? Colors.black87 : AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _PlaceTile extends StatelessWidget {
  const _PlaceTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.onTap,
    this.labelIsMain = false,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String? value;
  final VoidCallback onTap;

  /// For the date tile the first line (the date) is the bold one.
  final bool labelIsMain;

  @override
  Widget build(BuildContext context) {
    final top = Text(label,
        style: labelIsMain
            ? const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)
            : const TextStyle(fontSize: 12, color: AppColors.textMuted));
    final bottom = Text(value ?? 'Select city',
        style: labelIsMain
            ? const TextStyle(fontSize: 12.5, color: AppColors.textMuted)
            : TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: value == null ? AppColors.textMuted : Colors.black87,
              ));
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFD5DBE7)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [top, bottom])),
          ],
        ),
      ),
    );
  }
}

/// Hamburger menu: shortcuts that all lead to real screens.
class _MenuDrawer extends StatelessWidget {
  const _MenuDrawer({this.onOpenBookings, this.onOpenProfile});

  final VoidCallback? onOpenBookings;
  final VoidCallback? onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final user = session.user;
    void go(VoidCallback? action) {
      Navigator.pop(context); // close the drawer
      action?.call();
    }

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const UserAvatar(radius: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.fullName ?? 'Guest', style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text(user?.email ?? '',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.confirmation_number_outlined),
              title: const Text('My Bookings'),
              onTap: () => go(onOpenBookings),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profile'),
              onTap: () => go(onOpenProfile),
            ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Help & Support'),
              onTap: () => go(() => Navigator.pushNamed(context, AppRoutes.help)),
            ),
            const Spacer(),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.danger),
              title: const Text('Logout', style: TextStyle(color: AppColors.danger)),
              onTap: () => go(() => confirmLogout(context)),
            ),
          ],
        ),
      ),
    );
  }
}
