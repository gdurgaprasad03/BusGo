import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_exception.dart';
import '../services/api_service.dart';
import '../utils/app_config.dart';
import '../utils/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/app_text_field.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/demo_banner.dart';
import '../widgets/primary_button.dart';

/// "Forgot password" in two steps:
///  1. enter your email -> the server emails a 6-digit one-time code (valid for a few minutes, usable once)
///  2. enter the code and a new password.
/// The server gives the same answer whether or not the email is registered, so this screen cannot be used to find out
/// who has an account.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const _resendSeconds = 60;

  final _emailKey = GlobalKey<FormState>();
  final _resetKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _codeSent = false;
  bool _loading = false;
  String? _error;
  String? _offlineCode; // only in the offline demo build, which cannot send email
  bool? _emailEnabled; // null = unknown
  int _cooldown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    api.authConfig().then((config) {
      if (mounted) setState(() => _emailEnabled = config?.emailEnabled);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in [_email, _code, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _sendCode() async {
    if (_loading) return;
    if (!_emailKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await api.forgotPassword(_email.text.trim());
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _offlineCode = result.offlineCode;
      });
      _startCooldown();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_loading) return;
    if (!_resetKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await api.resetPassword(email: _email.text.trim(), code: _code.text.trim(), newPassword: _password.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated. Please log in with your new password.')),
      );
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthTitle(
                title: 'Reset Password',
                subtitle: _codeSent ? 'Enter the 6-digit code we emailed you' : 'We will email you a one-time code',
              ),
              const SizedBox(height: 24),
              if (_emailEnabled == false && !AppConfig.offlineDemo) ...[
                const DemoBanner(
                  icon: Icons.mail_outline,
                  text: 'This server is not set up to send email, so no code can arrive. '
                      'The administrator must configure email (see docs/EMAIL_SETUP.md).',
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              if (!_codeSent) _stepOne() else _stepTwo(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepOne() => Form(
        key: _emailKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              controller: _email,
              label: 'Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              validator: Validators.email,
              onSubmitted: _sendCode, // Enter sends the code
            ),
            if (_error != null) ...[const SizedBox(height: AppSpacing.md), ErrorBox(_error!)],
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(label: 'Send code', onPressed: _sendCode, loading: _loading),
          ],
        ),
      );

  Widget _stepTwo() => Form(
        key: _resetKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('If ${_email.text.trim()} is registered, a code is on its way. It expires in 15 minutes.',
                style: const TextStyle(color: AppColors.textMuted)),
            if (_offlineCode != null) ...[
              const SizedBox(height: AppSpacing.md),
              DemoBanner(
                icon: Icons.science_outlined,
                text: 'Offline demo: this build has no server, so no email can be sent. Your code is $_offlineCode.',
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _code,
              label: '6-digit code',
              icon: Icons.pin_outlined,
              keyboardType: TextInputType.number,
              digitsOnly: true,
              maxLength: 6,
              validator: (v) => (v == null || v.trim().length != 6) ? 'Enter the 6-digit code' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _password,
              label: 'New Password (min 8 characters)',
              icon: Icons.lock_outline,
              obscure: true,
              validator: Validators.password,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _confirm,
              label: 'Confirm New Password',
              icon: Icons.lock_outline,
              obscure: true,
              textInputAction: TextInputAction.done,
              validator: (v) => v != _password.text ? 'Passwords do not match' : null,
              onSubmitted: _resetPassword, // Enter resets the password
            ),
            if (_error != null) ...[const SizedBox(height: AppSpacing.md), ErrorBox(_error!)],
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(label: 'Reset Password', onPressed: _resetPassword, loading: _loading),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: _cooldown > 0 || _loading ? null : _sendCode,
              child: Text(_cooldown > 0 ? 'Resend code in ${_cooldown}s' : 'Resend code'),
            ),
            TextButton(
              onPressed: _loading ? null : () => setState(() {
                _codeSent = false;
                _error = null;
                _offlineCode = null;
              }),
              child: const Text('Use a different email'),
            ),
          ],
        ),
      );
}
