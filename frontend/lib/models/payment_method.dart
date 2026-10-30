import 'package:flutter/material.dart';

/// Simulated payment options. No real payment details are ever collected.
enum PaymentMethod {
  upi('UPI_DEMO', 'UPI (Google Pay, PhonePe, etc.)', 'UPI (demo)', Icons.account_balance_wallet_outlined),
  card('CARD_DEMO', 'Credit / Debit Card', 'Card (demo)', Icons.credit_card),
  netBanking('NET_BANKING_DEMO', 'Net Banking', 'Net banking (demo)', Icons.account_balance_outlined),
  wallet('WALLET_DEMO', 'Wallet (Paytm, Amazon Pay etc.)', 'Wallet (demo)', Icons.account_balance_wallet);

  const PaymentMethod(this.apiValue, this.label, this.shortLabel, this.icon);

  final String apiValue;
  final String label;
  final String shortLabel;
  final IconData icon;

  static String labelFor(String apiValue) => PaymentMethod.values
      .firstWhere((m) => m.apiValue == apiValue, orElse: () => PaymentMethod.upi)
      .shortLabel;
}
