import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

/// Small notice used to make clear that data or behaviour is simulated.
class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key, required this.text, this.icon = Icons.info_outline});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD79A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B4A00)))),
        ],
      ),
    );
  }
}
