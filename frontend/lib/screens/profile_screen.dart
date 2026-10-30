import 'package:flutter/material.dart';

import '../services/session.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import '../widgets/user_avatar.dart';
import 'logout_dialog.dart';

/// Screen 17: account overview and shortcuts.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.onOpenBookings});

  final VoidCallback onOpenBookings;

  @override
  Widget build(BuildContext context) {
    // Rebuilds automatically when the profile is edited (Session is a ChangeNotifier).
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final user = session.user;
        return Scaffold(
          appBar: AppBar(title: const Text('Profile')),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Row(
                children: [
                  const UserAvatar(radius: 34),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.fullName ?? 'Guest',
                            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(user?.phone ?? '', style: const TextStyle(color: AppColors.textMuted)),
                        Text(user?.email ?? '', style: const TextStyle(color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(),
              _MenuRow(icon: Icons.confirmation_number_outlined, label: 'My Bookings', onTap: onOpenBookings),
              _MenuRow(
                icon: Icons.person_outline,
                label: 'Edit Profile',
                onTap: () => Navigator.pushNamed(context, AppRoutes.editProfile),
              ),
              _MenuRow(
                icon: Icons.people_outline,
                label: 'Saved Passengers',
                onTap: () => Navigator.pushNamed(context, AppRoutes.savedPassengers),
              ),
              _MenuRow(
                icon: Icons.credit_card,
                label: 'Payment Methods',
                onTap: () => Navigator.pushNamed(context, AppRoutes.paymentMethods),
              ),
              _MenuRow(
                icon: Icons.notifications_none,
                label: 'Notifications',
                onTap: () => Navigator.pushNamed(context, AppRoutes.notifications),
              ),
              _MenuRow(
                icon: Icons.help_outline,
                label: 'Help & Support',
                onTap: () => Navigator.pushNamed(context, AppRoutes.help),
              ),
              _MenuRow(icon: Icons.logout, label: 'Logout', onTap: () => confirmLogout(context)),
            ],
          ),
        );
      },
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon),
          title: Text(label),
          trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
          onTap: onTap,
        ),
        const Divider(height: 1),
      ],
    );
  }
}
