import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_exception.dart';
import '../services/api_service.dart';
import '../utils/app_config.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import '../widgets/demo_banner.dart';

/// Screen 19: FAQs, contact, complaint (unavailable), terms, privacy and a connection check.
class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const _supportEmail = 'support@busgo.example';

  static const _faqs = [
    (
      'How do I book a ticket?',
      'On Home choose your route and date, search, pick a bus, select seats, enter passenger details and complete the (demo) payment.'
    ),
    (
      'Is the payment real?',
      'No. Payment is a simulation. No money is charged and no card, UPI or bank details are collected.'
    ),
    (
      'How do I cancel a booking?',
      'Open My Bookings, tap the trip, then choose Cancel Booking. Refunds follow the demo policy: 90% if 24 hours or more before departure, 50% for 6 to 24 hours, none under 6 hours.'
    ),
    (
      'Why can I not select a red seat?',
      'Red seats are already booked. Green seats are available and blue seats are the ones you selected.'
    ),
    (
      'Is the bus information live?',
      'No. Operators, schedules, ratings and prices are sample data created for this demonstration.'
    ),
  ];

  static const _terms =
      'BusGo is a demonstration application. By using it you understand that: bookings are not real and cannot be used to '
      'travel; no payment is taken; operators, schedules, ratings and prices are invented sample data; and your account data '
      'is stored only in this demo database. These terms are placeholder text, not a legal agreement.';

  static const _credits =
      'BusGo is a demonstration app built with Flutter and Spring Boot.\n\n'
      'Place names and locations (about 6,200 cities and towns in India) come from GeoNames, https://www.geonames.org, '
      'licensed under Creative Commons Attribution 4.0 (https://creativecommons.org/licenses/by/4.0/).\n\n'
      'Bus operators, schedules, ratings, fares and seat availability are fictional sample data. A place appearing in the '
      'list does not mean buses run there, and payments are simulated.';

  static const _privacy =
      'This demo stores the name, email address, mobile number and a securely hashed password you register with, together '
      'with your demo bookings, in the demo database. It does not collect payment details, location or contacts, and does '
      'not share data with third parties. This is placeholder text, not a formal privacy policy.';

  void _sheet(BuildContext context, {required String title, required Widget body}) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                body,
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFaqs(BuildContext context) => _sheet(
        context,
        title: 'FAQs',
        body: Column(
          children: [
            for (final faq in _faqs)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(faq.$1, style: const TextStyle(fontWeight: FontWeight.w600)),
                childrenPadding: const EdgeInsets.only(bottom: 12),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [Text(faq.$2, style: const TextStyle(color: AppColors.textMuted, height: 1.4))],
              ),
          ],
        ),
      );

  void _showContact(BuildContext context) => _sheet(
        context,
        title: 'Contact Us',
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Email'),
            const Text(_supportEmail, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(const ClipboardData(text: _supportEmail));
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Email address copied')));
                }
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy email address'),
            ),
            const SizedBox(height: 12),
            const DemoBanner(text: 'Demo only: this address is not monitored and there is no live chat or phone support.'),
          ],
        ),
      );

  Future<void> _checkServer(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Checking server connection...')));
    try {
      await api.checkHealth();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Connected to ${AppConfig.apiBaseUrl}')));
    } on ApiException catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const BackButton(), title: const Text('Help & Support')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _Row(icon: Icons.quiz_outlined, label: 'FAQs', onTap: () => _showFaqs(context)),
          _Row(icon: Icons.mail_outline, label: 'Contact Us', onTap: () => _showContact(context)),
          _Row(
            icon: Icons.report_gmailerrorred_outlined,
            label: 'Raise a Complaint',
            onTap: () => Navigator.pushNamed(context, AppRoutes.complaints),
          ),
          _Row(
            icon: Icons.description_outlined,
            label: 'Terms & Conditions',
            onTap: () => _sheet(context, title: 'Terms & Conditions', body: const Text(_terms, style: TextStyle(height: 1.45))),
          ),
          _Row(
            icon: Icons.privacy_tip_outlined,
            label: 'Privacy Policy',
            onTap: () => _sheet(context, title: 'Privacy Policy', body: const Text(_privacy, style: TextStyle(height: 1.45))),
          ),
          _Row(
            icon: Icons.info_outline,
            label: 'About & data credits',
            onTap: () => _sheet(context, title: 'About & data credits', body: const Text(_credits, style: TextStyle(height: 1.45))),
          ),
          _Row(icon: Icons.wifi_tethering, label: 'Check server connection', onTap: () => _checkServer(context)),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          leading: Icon(icon, color: Colors.black87),
          title: Text(label),
          trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
          onTap: onTap,
        ),
      ),
    );
  }
}
