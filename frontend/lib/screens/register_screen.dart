import 'package:flutter/material.dart';

import '../services/api_exception.dart';
import '../services/api_service.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/app_text_field.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/primary_button.dart';

/// Screen 6: create an account (name, email, mobile number, password).
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;
  Map<String, String> _fieldErrors = {};

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Server messages disappear as soon as the user edits a field, so they never block resubmitting.
  void _clearServerErrors() {
    if (_fieldErrors.isNotEmpty) setState(() => _fieldErrors = {});
  }

  Future<void> _submit() async {
    if (_loading) return; // Enter pressed again while a request is running
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await api.register(
        fullName: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _fieldErrors = e.fieldErrors;
      });
      _formKey.currentState!.validate(); // re-run so server field errors appear under the fields
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AuthTitle(title: 'Create Account', subtitle: 'Join and start booking now'),
                const SizedBox(height: 28),
                AppTextField(
                  controller: _name,
                  label: 'Name',
                  icon: Icons.person_outline,
                  validator: Validators.name,
                  serverError: _fieldErrors['fullName'],
                  onChanged: (_) => _clearServerErrors(),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _email,
                  label: 'Email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.email,
                  serverError: _fieldErrors['email'],
                  onChanged: (_) => _clearServerErrors(),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _phone,
                  label: 'Mobile Number',
                  icon: Icons.phone_android_outlined,
                  keyboardType: TextInputType.phone,
                  digitsOnly: true,
                  maxLength: 10,
                  validator: Validators.phone,
                  serverError: _fieldErrors['phone'],
                  onChanged: (_) => _clearServerErrors(),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _password,
                  label: 'Password (min 8 characters)',
                  icon: Icons.lock_outline,
                  obscure: true,
                  textInputAction: TextInputAction.done,
                  validator: Validators.password,
                  serverError: _fieldErrors['password'],
                  onChanged: (_) => _clearServerErrors(),
                  onSubmitted: _submit, // Enter signs up, same as the button
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_error != null) ...[ErrorBox(_error!), const SizedBox(height: AppSpacing.md)],
                PrimaryButton(label: 'Sign Up', onPressed: _submit, loading: _loading),
                const SizedBox(height: AppSpacing.md),
                const OrDivider(),
                const SizedBox(height: AppSpacing.md),
                GoogleSignInButton(
                  onSignedIn: () => Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have an account?', style: TextStyle(color: AppColors.textMuted)),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Login', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
