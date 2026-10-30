import 'package:flutter/material.dart';

import 'app.dart';
import 'services/api_service.dart';
import 'utils/app_routes.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // If the server says our login expired, send the user back to the login screen.
  api.onSessionExpired = () {
    navigatorKey.currentState?.pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  };

  runApp(const BusGoApp());
}
