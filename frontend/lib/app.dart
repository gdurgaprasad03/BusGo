import 'package:flutter/material.dart';

import 'models/booking.dart';
import 'models/booking_draft.dart';
import 'models/search_params.dart';
import 'models/trip.dart';
import 'screens/booking_confirmation_screen.dart';
import 'screens/booking_details_screen.dart';
import 'screens/bus_details_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/filters_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/payment_methods_screen.dart';
import 'screens/raise_complaint_screen.dart';
import 'screens/saved_passengers_screen.dart';
import 'screens/help_support_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'screens/onboarding_screen.dart';
import 'screens/passenger_details_screen.dart';
import 'screens/payment_screen.dart';
import 'screens/register_screen.dart';
import 'screens/search_results_screen.dart';
import 'screens/seat_selection_screen.dart';
import 'screens/splash_screen.dart';
import 'utils/app_routes.dart';
import 'utils/app_theme.dart';

/// Lets code outside widgets (e.g. the "session expired" callback) navigate.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class BusGoApp extends StatelessWidget {
  const BusGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BusGo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      navigatorKey: navigatorKey,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: _onGenerateRoute,
    );
  }

  /// Maps a route name to a screen. Typed arguments are unpacked here, in one place.
  static Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    final args = settings.arguments;
    final Widget screen;
    switch (settings.name) {
      case AppRoutes.splash:
        screen = const SplashScreen();
      case AppRoutes.onboarding:
        screen = const OnboardingScreen();
      case AppRoutes.login:
        screen = const LoginScreen();
      case AppRoutes.register:
        screen = const RegisterScreen();
      case AppRoutes.home:
        screen = MainShell(initialTab: args is int ? args : 0);
      case AppRoutes.results:
        screen = SearchResultsScreen(params: args as SearchParams);
      case AppRoutes.filters:
        screen = FiltersScreen(initial: args as TripFilter);
      case AppRoutes.busDetails:
        screen = BusDetailsScreen(tripId: args as int);
      case AppRoutes.seats:
        screen = SeatSelectionScreen(trip: args as Trip);
      case AppRoutes.passengers:
        screen = PassengerDetailsScreen(draft: args as BookingDraft);
      case AppRoutes.payment:
        screen = PaymentScreen(draft: args as BookingDraft);
      case AppRoutes.confirmation:
        screen = BookingConfirmationScreen(booking: args as Booking);
      case AppRoutes.bookingDetails:
        screen = BookingDetailsScreen(bookingId: args as int);
      case AppRoutes.editProfile:
        screen = const EditProfileScreen();
      case AppRoutes.help:
        screen = const HelpSupportScreen();
      case AppRoutes.forgotPassword:
        screen = const ForgotPasswordScreen();
      case AppRoutes.savedPassengers:
        screen = const SavedPassengersScreen();
      case AppRoutes.paymentMethods:
        screen = const PaymentMethodsScreen();
      case AppRoutes.complaints:
        screen = const RaiseComplaintScreen();
      case AppRoutes.notifications:
        screen = const NotificationsScreen();
      default:
        screen = const SplashScreen();
    }
    return MaterialPageRoute<dynamic>(builder: (_) => screen, settings: settings);
  }
}
