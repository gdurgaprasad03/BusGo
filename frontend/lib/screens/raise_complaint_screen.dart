import 'package:flutter/material.dart';

import '../models/complaint.dart';
import '../services/api_exception.dart';
import '../services/api_service.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/validators.dart';
import '../widgets/app_text_field.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/demo_banner.dart';
import '../widgets/primary_button.dart';
import '../widgets/state_views.dart';

/// Raise a complaint (optionally about one of your bookings) and see the ones you raised before.
class RaiseComplaintScreen extends StatefulWidget {
  const RaiseComplaintScreen({super.key});

  @override
  State<RaiseComplaintScreen> createState() => _RaiseComplaintScreenState();
}

class _RaiseComplaintScreenState extends State<RaiseComplaintScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final _formKey = GlobalKey<FormState>();
  final _booking = TextEditingController();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  bool _sending = false;
  String? _error;
  late Future<List<Complaint>> _history = api.myComplaints();

  @override
  void dispose() {
    _tabs.dispose();
    _booking.dispose();
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  void _reloadHistory() {
    setState(() {
      _history = api.myComplaints();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final complaint = await api.raiseComplaint(
        bookingReference: _booking.text.trim(),
        subject: _subject.text.trim(),
        message: _message.text.trim(),
      );
      if (!mounted) return;
      _booking.clear();
      _subject.clear();
      _message.clear();
      _formKey.currentState!.reset();
      _reloadHistory();
      _tabs.animateTo(1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Complaint ${complaint.reference} submitted.')),
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Raise a Complaint'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'New complaint'), Tab(text: 'My complaints')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    AppTextField(
                      controller: _booking,
                      label: 'Booking ID (optional)',
                      icon: Icons.confirmation_number_outlined,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _subject,
                      label: 'Subject',
                      maxLength: 120,
                      validator: (v) => Validators.required(v, 'Subject'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _message,
                      minLines: 4,
                      maxLines: 7,
                      maxLength: 1000,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: (v) => (v == null || v.trim().length < 10) ? 'Please describe the problem (at least 10 characters)' : null,
                      decoration: const InputDecoration(labelText: 'Describe the problem', alignLabelWithHint: true),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[const SizedBox(height: AppSpacing.sm), ErrorBox(_error!)],
              const SizedBox(height: AppSpacing.md),
              PrimaryButton(label: 'Submit Complaint', onPressed: _submit, loading: _sending),
              const SizedBox(height: AppSpacing.md),
              const DemoBanner(
                text: 'Demo: complaints are saved in the demo database. Nobody monitors them or replies.',
              ),
            ],
          ),
          FutureBuilder<List<Complaint>>(
            future: _history,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) return const LoadingView();
              if (snapshot.hasError) {
                final e = snapshot.error;
                return ErrorView(
                  message: e is ApiException ? e.message : 'Could not load your complaints.',
                  onRetry: _reloadHistory,
                );
              }
              final list = snapshot.data!;
              if (list.isEmpty) {
                return const EmptyView(
                  icon: Icons.report_gmailerrorred_outlined,
                  title: 'No complaints yet',
                  message: 'Complaints you raise will be listed here.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final c = list[i];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(c.subject,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(c.status,
                                    style: const TextStyle(
                                        color: AppColors.warning, fontWeight: FontWeight.w700, fontSize: 11.5)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('${c.reference}  |  ${Fmt.dateTime(c.createdAt)}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                          if (c.bookingReference != null)
                            Text('Booking: ${c.bookingReference}',
                                style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                          const SizedBox(height: 6),
                          Text(c.message),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
