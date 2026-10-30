import 'package:flutter/material.dart';

/// The BusGo design system: one white-and-blue Material 3 theme used by every screen.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF1A5FE0);
  static const Color primaryDark = Color(0xFF0D47A1);
  static const Color background = Colors.white;
  static const Color surfaceTint = Color(0xFFF5F8FF);
  static const Color border = Color(0xFFE3E8F1);
  static const Color seatAvailable = Color(0xFF2E9E5B); // green
  static const Color seatSelected = Color(0xFF1A5FE0); // blue
  static const Color seatBooked = Color(0xFFE57373); // red
  static const Color textMuted = Color(0xFF5B6575);
  static const Color danger = Color(0xFFD32F2F);
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFE65100);
  static const Color star = Color(0xFFF59E0B);
  static const Color logoRed = Color(0xFFE53935);
}

class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(primary: AppColors.primary);

    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.w600),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: border(const Color(0xFFD5DBE7)),
        enabledBorder: border(const Color(0xFFD5DBE7)),
        focusedBorder: border(AppColors.primary, 2),
        errorBorder: border(AppColors.danger),
        focusedErrorBorder: border(AppColors.danger, 2),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: states.contains(WidgetState.selected) ? AppColors.primary : AppColors.textMuted,
            )),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected) ? AppColors.primary : AppColors.textMuted,
            )),
      ),
    );
  }
}
