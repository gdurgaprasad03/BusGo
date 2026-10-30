import 'package:flutter/material.dart';

import '../services/session.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';

/// Round profile picture: the photo picked on this device, or the user's initials.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, this.radius = 32});

  final double radius;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final photo = session.avatar;
        return CircleAvatar(
          radius: radius,
          backgroundColor: AppColors.primary.withValues(alpha: 0.14),
          backgroundImage: photo == null ? null : MemoryImage(photo),
          child: photo != null
              ? null
              : Text(
                  Fmt.initials(session.user?.fullName ?? ''),
                  style: TextStyle(color: AppColors.primary, fontSize: radius * 0.7, fontWeight: FontWeight.w800),
                ),
        );
      },
    );
  }
}
