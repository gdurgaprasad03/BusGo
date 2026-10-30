import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

/// "Label ........ value" row used on ticket, payment and details screens.
class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.label, required this.value, this.bold = false, this.valueColor});

  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: AppColors.textMuted))),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bold section heading inside a card or page.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      );
}
