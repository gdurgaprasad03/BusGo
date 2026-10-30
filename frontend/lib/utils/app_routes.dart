/// Named routes. Screens are opened with Navigator.pushNamed(context, AppRoutes.xyz, arguments: ...).
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String results = '/results';
  static const String filters = '/filters';
  static const String busDetails = '/bus-details';
  static const String seats = '/seats';
  static const String passengers = '/passengers';
  static const String payment = '/payment';
  static const String confirmation = '/confirmation';
  static const String bookingDetails = '/booking-details';
  static const String editProfile = '/edit-profile';
  static const String help = '/help';
  static const String forgotPassword = '/forgot-password';
  static const String savedPassengers = '/saved-passengers';
  static const String paymentMethods = '/payment-methods';
  static const String complaints = '/complaints';
  static const String notifications = '/notifications';
}
