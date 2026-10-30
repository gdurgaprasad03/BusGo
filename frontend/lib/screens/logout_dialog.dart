import 'package:flutter/material.dart';

import '../services/google_auth.dart';
import '../services/session.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';

/// Screen 20: logout confirmation dialog. On "Logout" the session is cleared and the user
/// is taken to the login screen with the navigation history wiped.
Future<void> confirmLogout(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Logout?', style: TextStyle(fontWeight: FontWeight.w800)),
      content: const Text('Are you sure you want to logout from your account?'),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  minimumSize: const Size.fromHeight(46),
                ),
                child: const Text('Logout'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  await GoogleAuth.signOut(); // forget the Google account on this phone so the next person can choose theirs
  await session.signOut();
  if (context.mounted) {
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
  }
}
