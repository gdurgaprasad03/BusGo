import 'package:flutter/material.dart';

import '../services/api_exception.dart';
import '../services/api_service.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/app_text_field.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/primary_button.dart';

/// Screen 5: login with email or mobile number + password.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return; // Enter pressed again while a login is already running
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await api.login(identifier: _identifier.text.trim(), password: _password.text);
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: Navigator.of(context).canPop() ? const BackButton() : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AuthTitle(title: 'Welcome Back', subtitle: 'Login to continue your journey'),
                const SizedBox(height: 32),
                AppTextField(
                  controller: _identifier,
                  label: 'Email or Mobile Number',
                  icon: Icons.person_outline,
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.emailOrPhone,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _password,
                  label: 'Password',
                  icon: Icons.lock_outline,
                  obscure: true,
                  textInputAction: TextInputAction.done,
                  validator: (v) => Validators.required(v, 'Password'),
                  onSubmitted: _submit, // Enter logs in, same as the Login button
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.forgotPassword),
                    child: const Text('Forgot Password?', style: TextStyle(fontSize: 13)),
                  ),
                ),
                if (_error != null) ...[ErrorBox(_error!), const SizedBox(height: AppSpacing.md)],
                PrimaryButton(label: 'Login', onPressed: _submit, loading: _loading),
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
                    const Text("Don't have an account?", style: TextStyle(color: AppColors.textMuted)),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, AppRoutes.register),
                      child: const Text('Sign Up', style: TextStyle(fontWeight: FontWeight.w700)),
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
