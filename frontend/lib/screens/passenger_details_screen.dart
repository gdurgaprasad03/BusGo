import 'package:flutter/material.dart';

import '../models/booking_draft.dart';
import '../services/api_exception.dart';
import '../services/api_service.dart';
import '../services/session.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/validators.dart';
import '../widgets/app_text_field.dart';
import '../widgets/info_row.dart';
import '../widgets/primary_button.dart';
import 'saved_passengers_screen.dart';

/// Screen 12: one passenger form per selected seat, contact details and boarding information.
class PassengerDetailsScreen extends StatefulWidget {
  const PassengerDetailsScreen({super.key, required this.draft});

  final BookingDraft draft;

  @override
  State<PassengerDetailsScreen> createState() => _PassengerDetailsScreenState();
}

class _PassengerDetailsScreenState extends State<PassengerDetailsScreen> {
  static const _genders = {'MALE': 'Male', 'FEMALE': 'Female', 'OTHER': 'Other'};

  final _formKey = GlobalKey<FormState>();
  late final List<TextEditingController> _names;
  late final List<TextEditingController> _ages;
  late final List<String> _genderValues;
  late final List<bool> _saveFlags;
  late final TextEditingController _phone;
  late final TextEditingController _email;

  @override
  void initState() {
    super.initState();
    final count = widget.draft.seatNumbers.length;
    _names = List.generate(count, (_) => TextEditingController());
    _ages = List.generate(count, (_) => TextEditingController());
    _genderValues = List.filled(count, 'MALE');
    _saveFlags = List.filled(count, false);
    // Pre-fill the first passenger and the contact details from the logged-in user.
    final user = session.user;
    if (user != null) _names.first.text = user.fullName;
    _phone = TextEditingController(text: user?.phone ?? '');
    _email = TextEditingController(text: user?.email ?? '');
  }

  @override
  void dispose() {
    for (final c in [..._names, ..._ages, _phone, _email]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Fills passenger [i] from one of the user's saved passengers.
  Future<void> _useSaved(int i) async {
    final p = await pickSavedPassenger(context);
    if (p == null || !mounted) return;
    setState(() {
      _names[i].text = p.name;
      _ages[i].text = '${p.age}';
      _genderValues[i] = p.gender;
      _saveFlags[i] = false; // already saved
    });
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;
    final draft = widget.draft;

    // Save the passengers the user ticked. A failure (e.g. already saved) must not block the booking.
    for (var i = 0; i < draft.seatNumbers.length; i++) {
      if (!_saveFlags[i]) continue;
      try {
        await api.addSavedPassenger(
            name: _names[i].text.trim(), age: int.parse(_ages[i].text.trim()), gender: _genderValues[i]);
      } on ApiException {
        // ignore
      }
    }
    if (!mounted) return;
    draft.passengers = [
      for (var i = 0; i < draft.seatNumbers.length; i++)
        PassengerInput(
          seatNumber: draft.seatNumbers[i],
          name: _names[i].text.trim(),
          age: int.parse(_ages[i].text.trim()),
          gender: _genderValues[i],
        ),
    ];
    draft.contactPhone = _phone.text.trim();
    draft.contactEmail = _email.text.trim();
    Navigator.pushNamed(context, AppRoutes.payment, arguments: draft);
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final trip = draft.trip;
    return Scaffold(
      appBar: AppBar(leading: const BackButton(), title: const Text('Boarding Details')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionTitle('Boarding and dropping'),
                    InfoRow(label: 'Route', value: '${trip.source} to ${trip.destination}'),
                    InfoRow(label: 'Departure', value: Fmt.dateTime(trip.departureTime)),
                    InfoRow(label: 'Boarding point', value: trip.boardingPoint),
                    InfoRow(label: 'Dropping point', value: trip.droppingPoint),
                    InfoRow(label: 'Seats', value: draft.seatNumbers.join(', ')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            for (var i = 0; i < draft.seatNumbers.length; i++) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: SectionTitle('Passenger ${i + 1}')),
                          TextButton.icon(
                            onPressed: () => _useSaved(i),
                            icon: const Icon(Icons.people_outline, size: 18),
                            label: const Text('Saved'),
                          ),
                        ],
                      ),
                      AppTextField(
                        controller: _names[i],
                        label: 'Full Name',
                        validator: Validators.name,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: _ages[i],
                              label: 'Age',
                              keyboardType: TextInputType.number,
                              digitsOnly: true,
                              maxLength: 3,
                              validator: Validators.age,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _genderValues[i],
                              decoration: const InputDecoration(labelText: 'Gender'),
                              items: [
                                for (final e in _genders.entries)
                                  DropdownMenuItem(value: e.key, child: Text(e.value)),
                              ],
                              onChanged: (v) => setState(() => _genderValues[i] = v ?? 'MALE'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      // The seat was chosen on the previous screen, so it is shown read-only.
                      TextFormField(
                        initialValue: draft.seatNumbers[i],
                        enabled: false,
                        decoration: const InputDecoration(labelText: 'Seat Number'),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _saveFlags[i],
                        title: const Text('Save this passenger for next time'),
                        onChanged: (v) => setState(() => _saveFlags[i] = v ?? false),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionTitle('Contact details'),
                    AppTextField(
                      controller: _phone,
                      label: 'Mobile number',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      digitsOnly: true,
                      maxLength: 10,
                      validator: Validators.phone,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _email,
                      label: 'Email',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      validator: Validators.email,
                      onSubmitted: _continue, // Enter goes to payment
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: PrimaryButton(
            label: 'Proceed to Payment',
            onPressed: _continue,
          ),
        ),
      ),
    );
  }
}
