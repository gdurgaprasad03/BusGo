import 'package:flutter/material.dart';

import '../services/session.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import '../widgets/primary_button.dart';

class _OnboardingPage {
  final String title;
  final String text;
  final Widget art;
  const _OnboardingPage(this.title, this.text, this.art);
}

/// Screens 2-4: three swipeable introduction pages (Skip / Next / Get Started).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _pages = [
    _OnboardingPage(
      'Find Buses\nAll Over India',
      'Search buses from multiple operators for your destination',
      _Art(main: Icons.directions_bus_filled, badges: [Icons.location_on, Icons.location_city]),
    ),
    _OnboardingPage(
      'Easy & Secure\nBooking',
      'Choose your seats and book in just a few steps',
      _Art(main: Icons.phone_android, badges: [Icons.check_circle, Icons.lock_outline]),
    ),
    _OnboardingPage(
      'Track & Manage\nYour Bookings',
      'View your upcoming and past trips anytime',
      _Art(main: Icons.luggage, badges: [Icons.event_seat, Icons.confirmation_number_outlined]),
    ),
  ];

  final PageController _controller = PageController();
  int _index = 0;

  bool get _isLast => _index == _pages.length - 1;

  Future<void> _finish() async {
    await session.markOnboardingSeen();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: const Text('Skip', style: TextStyle(color: AppColors.textMuted, fontSize: 15)),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) {
                  final page = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      children: [
                        Expanded(child: Center(child: page.art)),
                        Text(page.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.25)),
                        const SizedBox(height: 14),
                        Text(page.text,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 15, color: AppColors.textMuted, height: 1.4)),
                        const SizedBox(height: 24),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    height: 6,
                    width: i == _index ? 16 : 6,
                    decoration: BoxDecoration(
                      color: i == _index ? AppColors.primary : AppColors.primary.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
              child: PrimaryButton(label: _isLast ? 'Get Started' : 'Next', onPressed: _next),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple illustration built from icons: a soft blue blob with a main icon and floating badges.
class _Art extends StatelessWidget {
  const _Art({required this.main, required this.badges});

  final IconData main;
  final List<IconData> badges;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      width: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(130),
            ),
          ),
          Container(
            height: 170,
            width: 170,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(main, size: 96, color: AppColors.primary),
          ),
          Positioned(top: 18, right: 34, child: _badge(badges[0])),
          Positioned(bottom: 26, left: 30, child: _badge(badges[1])),
        ],
      ),
    );
  }

  Widget _badge(IconData icon) => Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 3))],
        ),
        child: Icon(icon, color: AppColors.logoRed, size: 26),
      );
}
