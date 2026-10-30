/// Form validators. Each returns an error message, or null when the value is fine.
/// They mirror the backend's rules, but the backend still re-checks everything.
class Validators {
  Validators._();

  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? required(String? v, [String label = 'This field']) =>
      (v == null || v.trim().isEmpty) ? '$label is required' : null;

  static String? name(String? v) {
    if (v == null || v.trim().isEmpty) return 'Name is required';
    if (v.trim().length > 100) return 'Name is too long';
    return null;
  }

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    if (!_email.hasMatch(v.trim())) return 'Enter a valid email address';
    return null;
  }

  /// Login accepts either an email address or a 10-digit mobile number.
  static String? emailOrPhone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email or mobile number is required';
    final t = v.trim();
    if (_email.hasMatch(t) || RegExp(r'^\d{10}$').hasMatch(t)) return null;
    return 'Enter a valid email or 10-digit mobile number';
  }

  static String? phone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Phone number is required';
    if (!RegExp(r'^\d{10}$').hasMatch(v.trim())) return 'Phone must be 10 digits';
    return null;
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  static String? age(String? v) {
    if (v == null || v.trim().isEmpty) return 'Age is required';
    final n = int.tryParse(v.trim());
    if (n == null || n < 1 || n > 120) return 'Enter an age from 1 to 120';
    return null;
  }
}
