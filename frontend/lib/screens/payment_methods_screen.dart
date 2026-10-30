import 'package:flutter/material.dart';

import '../models/payment_method.dart';
import '../services/session.dart';
import '../utils/app_theme.dart';
import '../widgets/demo_banner.dart';

/// Choose the default payment method that is pre-selected at checkout.
/// Only the choice of method is stored (on this device). No card, UPI or bank details are ever collected.
class PaymentMethodsScreen extends StatelessWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const BackButton(), title: const Text('Payment Methods')),
      body: ListenableBuilder(
        listenable: session,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            const DemoBanner(
              icon: Icons.science_outlined,
              text: 'Payments in BusGo are simulated. We never ask for or store card numbers, UPI IDs or bank '
                  'details. Here you only choose which demo method is pre-selected at checkout.',
            ),
            const SizedBox(height: AppSpacing.md),
            const Text('Default payment method', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            RadioGroup<PaymentMethod>(
              groupValue: session.preferredPayment,
              onChanged: (m) async {
                if (m == null) return;
                await session.setPreferredPayment(m);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${m.shortLabel} is now your default.')),
                  );
                }
              },
              child: Column(
                children: [
                  for (final method in PaymentMethod.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        child: RadioListTile<PaymentMethod>(
                          value: method,
                          controlAffinity: ListTileControlAffinity.trailing,
                          secondary: Icon(method.icon, color: AppColors.primary),
                          title: Text(method.label, style: const TextStyle(fontSize: 14.5)),
                          subtitle: method == session.preferredPayment
                              ? const Text('Default', style: TextStyle(fontSize: 11.5, color: AppColors.success))
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
