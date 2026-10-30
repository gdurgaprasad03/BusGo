import 'package:flutter/material.dart';

import '../services/api_exception.dart';
import '../services/api_service.dart';
import '../services/session.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';

/// Screen 1. Logo and tagline, then decides where to go:
/// first launch -> onboarding, logged in -> home, otherwise -> login.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    await Future.wait([session.load(), Future<void>.delayed(const Duration(milliseconds: 1600))]);
    if (!mounted) return;

    String next;
    if (session.isLoggedIn) {
      next = AppRoutes.home;
      try {
        await api.getProfile(); // confirms the saved token is still accepted
      } on ApiException catch (e) {
        // Offline is fine (stay logged in); an invalid token means log in again.
        if (e.isUnauthorized) next = AppRoutes.login;
      }
    } else {
      next = session.onboardingSeen ? AppRoutes.login : AppRoutes.onboarding;
    }
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 5),
            const Icon(Icons.directions_bus_filled, size: 84, color: AppColors.logoRed),
            const SizedBox(height: 6),
            const Text('BusGo',
                style: TextStyle(color: AppColors.logoRed, fontSize: 34, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Your Journey, Our Priority', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
            const Spacer(flex: 4),
            const SizedBox(
              width: 120,
              child: LinearProgressIndicator(minHeight: 4, borderRadius: BorderRadius.all(Radius.circular(4))),
            ),
            const SizedBox(height: 16),
            const Text('Demo application - sample data only',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}
