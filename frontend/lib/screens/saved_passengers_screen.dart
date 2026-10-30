import 'package:flutter/material.dart';

import '../models/saved_passenger.dart';
import '../services/api_exception.dart';
import '../services/api_service.dart';
import '../utils/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/app_text_field.dart';
import '../widgets/primary_button.dart';
import '../widgets/state_views.dart';

/// Manage saved passengers: list, add and delete. They can be picked when booking.
class SavedPassengersScreen extends StatefulWidget {
  const SavedPassengersScreen({super.key});

  @override
  State<SavedPassengersScreen> createState() => _SavedPassengersScreenState();
}

class _SavedPassengersScreenState extends State<SavedPassengersScreen> {
  late Future<List<SavedPassenger>> _future = api.savedPassengers();

  void _reload() {
    setState(() {
      _future = api.savedPassengers();
    });
  }

  Future<void> _add() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _AddPassengerSheet(),
    );
    if (added == true) _reload();
  }

  Future<void> _delete(SavedPassenger p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete passenger?'),
        content: Text('${p.name} will be removed from your saved passengers.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await api.deleteSavedPassenger(p.id);
      _reload();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const BackButton(), title: const Text('Saved Passengers')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add passenger'),
      ),
      body: FutureBuilder<List<SavedPassenger>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const LoadingView();
          if (snapshot.hasError) {
            final e = snapshot.error;
            return ErrorView(
              message: e is ApiException ? e.message : 'Could not load saved passengers.',
              onRetry: _reload,
            );
          }
          final list = snapshot.data!;
          if (list.isEmpty) {
            return EmptyView(
              icon: Icons.people_outline,
              title: 'No saved passengers',
              message: 'Save people you travel with to fill in booking forms faster.',
              actionLabel: 'Add passenger',
              onAction: _add,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final p = list[i];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: const Icon(Icons.person, color: AppColors.primary),
                  ),
                  title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${p.age} yrs, ${p.genderLabel}'),
                  trailing: IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                    onPressed: () => _delete(p),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _AddPassengerSheet extends StatefulWidget {
  const _AddPassengerSheet();

  @override
  State<_AddPassengerSheet> createState() => _AddPassengerSheetState();
}

class _AddPassengerSheetState extends State<_AddPassengerSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _age = TextEditingController();
  String _gender = 'MALE';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await api.addSavedPassenger(name: _name.text.trim(), age: int.parse(_age.text.trim()), gender: _gender);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Add passenger', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              AppTextField(controller: _name, label: 'Full Name', validator: Validators.name),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _age,
                      label: 'Age',
                      keyboardType: TextInputType.number,
                      digitsOnly: true,
                      maxLength: 3,
                      validator: Validators.age,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _gender,
                      decoration: const InputDecoration(labelText: 'Gender'),
                      items: const [
                        DropdownMenuItem(value: 'MALE', child: Text('Male')),
                        DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
                        DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                      ],
                      onChanged: (v) => setState(() => _gender = v ?? 'MALE'),
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: AppColors.danger)),
              ],
              const SizedBox(height: 16),
              PrimaryButton(label: 'Save passenger', onPressed: _save, loading: _saving),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet used on the booking form: pick one saved passenger. Returns it, or null.
Future<SavedPassenger?> pickSavedPassenger(BuildContext context) {
  return showModalBottomSheet<SavedPassenger>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
        child: FutureBuilder<List<SavedPassenger>>(
          future: api.savedPassengers(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(height: 160, child: LoadingView());
            }
            if (snapshot.hasError) {
              final e = snapshot.error;
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Text(e is ApiException ? e.message : 'Could not load saved passengers.'),
              );
            }
            final list = snapshot.data!;
            if (list.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Text('You have no saved passengers yet. Add them from Profile > Saved Passengers, '
                    'or tick "Save this passenger" while booking.'),
              );
            }
            return ListView(
              shrinkWrap: true,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text('Choose a saved passenger', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
                for (final p in list)
                  ListTile(
                    leading: const Icon(Icons.person, color: AppColors.primary),
                    title: Text(p.name),
                    subtitle: Text('${p.age} yrs, ${p.genderLabel}'),
                    onTap: () => Navigator.pop(ctx, p),
                  ),
              ],
            );
          },
        ),
      ),
    ),
  );
}
