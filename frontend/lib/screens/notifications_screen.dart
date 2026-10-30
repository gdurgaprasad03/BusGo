import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../services/api_exception.dart';
import '../services/api_service.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/state_views.dart';

/// In-app notifications built from the user's bookings: confirmations, cancellations and trip reminders.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<AppNotification>> _future = _load();

  Future<List<AppNotification>> _load() async =>
      AppNotification.fromBookings(await api.myBookings(), DateTime.now());

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  (IconData, Color) _style(NotificationKind kind) => switch (kind) {
        NotificationKind.confirmed => (Icons.check_circle_outline, AppColors.success),
        NotificationKind.cancelled => (Icons.cancel_outlined, AppColors.danger),
        NotificationKind.reminder => (Icons.alarm, AppColors.warning),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const BackButton(), title: const Text('Notifications')),
      body: FutureBuilder<List<AppNotification>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const LoadingView();
          if (snapshot.hasError) {
            final e = snapshot.error;
            return ErrorView(
              message: e is ApiException ? e.message : 'Could not load notifications.',
              onRetry: _reload,
            );
          }
          final list = snapshot.data!;
          if (list.isEmpty) {
            return const EmptyView(
              icon: Icons.notifications_none,
              title: 'No notifications yet',
              message: 'Booking confirmations, cancellations and trip reminders will appear here.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final n = list[i];
                final (icon, color) = _style(n.kind);
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.12),
                      child: Icon(icon, color: color),
                    ),
                    title: Text(n.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${n.message}\n${Fmt.dateTime(n.time)}'),
                    isThreeLine: true,
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.bookingDetails, arguments: n.bookingId),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
