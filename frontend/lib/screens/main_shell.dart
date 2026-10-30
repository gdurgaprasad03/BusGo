import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'my_bookings_screen.dart';
import 'profile_screen.dart';

/// Holds the bottom navigation bar (Home / Bookings / Profile) and the three tab screens.
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final GlobalKey<MyBookingsScreenState> _bookingsKey = GlobalKey<MyBookingsScreenState>();
  late int _index = widget.initialTab.clamp(0, 2);

  void _select(int i) {
    setState(() => _index = i);
    if (i == 1) _bookingsKey.currentState?.reload(); // always show fresh bookings
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack keeps each tab alive so switching tabs does not lose state.
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(onOpenBookings: () => _select(1), onOpenProfile: () => _select(2)),
          MyBookingsScreen(key: _bookingsKey, onSearchBuses: () => _select(0)),
          ProfileScreen(onOpenBookings: () => _select(1)),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), selectedIcon: Icon(Icons.search), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.confirmation_number_outlined),
              selectedIcon: Icon(Icons.confirmation_number),
              label: 'Bookings'),
          NavigationDestination(
              icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
