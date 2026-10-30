import 'package:flutter/material.dart';

import '../services/api_exception.dart';
import '../services/api_service.dart';
import '../services/google_auth.dart';
import '../utils/app_theme.dart';

/// Page title block used on login and sign-up ("Welcome Back" + grey subtitle).
class AuthTitle extends StatelessWidget {
  const AuthTitle({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(subtitle, style: const TextStyle(fontSize: 15, color: AppColors.textMuted)),
      ],
    );
  }
}

/// "---- OR ----" separator.
class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider()),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('OR', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ),
        Expanded(child: Divider()),
      ],
    );
  }
}

/// "Continue with Google". It only works when Google sign-in is configured (a Google Cloud OAuth client id in
/// this build AND on the server). Otherwise it looks disabled and explains why when tapped, instead of pretending.
class GoogleSignInButton extends StatefulWidget {
  const GoogleSignInButton({super.key, required this.onSignedIn});

  /// Called after the server accepted the Google sign-in (the session is already stored).
  final VoidCallback onSignedIn;

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  bool? _serverEnabled; // null = not known yet (or the server could not be reached)
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (GoogleAuth.unavailableReason == null) {
      api.googleEnabledOnServer().then((enabled) {
        if (mounted) setState(() => _serverEnabled = enabled);
      });
    }
  }

  /// Null when the button can be used.
  String? get _reason => GoogleAuth.unavailableReason ?? (_serverEnabled == false ? 'Not enabled on the server' : null);

  void _say(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _onTap() async {
    final reason = _reason;
    if (reason != null) {
      _say('Google sign-in is unavailable: $reason. Please use email or mobile number.');
      return;
    }
    setState(() => _loading = true);
    try {
      final token = await GoogleAuth.getIdToken();
      await api.googleLogin(token);
      if (mounted) widget.onSignedIn();
    } on GoogleAuthException catch (e) {
      if (mounted) _say(e.message);
    } on ApiException catch (e) {
      if (mounted) _say(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reason = _reason;
    final disabled = reason != null;
    return Semantics(
      button: true,
      enabled: !disabled,
      label: disabled ? 'Continue with Google, unavailable: $reason' : 'Continue with Google',
      child: OutlinedButton(
        onPressed: _loading ? null : _onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: disabled ? AppColors.textMuted : Colors.black87,
          side: BorderSide(color: disabled ? const Color(0xFFE3E8F1) : const Color(0xFFD5DBE7)),
          minimumSize: const Size.fromHeight(54),
        ),
        child: _loading
            ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('G',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: disabled ? AppColors.textMuted : const Color(0xFFDB4437))),
                  const SizedBox(width: 12),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Continue with Google', style: TextStyle(fontWeight: FontWeight.w600)),
                      if (disabled)
                        Text('Unavailable: $reason', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

/// Small error box shown above a submit button.
class ErrorBox extends StatelessWidget {
  const ErrorBox(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(message, style: const TextStyle(color: AppColors.danger)),
    );
  }
}
