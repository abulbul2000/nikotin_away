import 'package:flutter/material.dart';

class AppTheme {
  /// Sampled from the logo itself, whose dominant colour is #0090B0 with a
  /// teal-to-mint gradient across the butterfly. Brightened a little from
  /// that measured value so it stays legible as a control colour on the dark
  /// navy ground. The previous accent was #00C853, a saturated grass green
  /// that appears nowhere in the artwork — buttons and progress bars read as
  /// belonging to a different app than the logo above them.
  static const Color brandPrimary = Color(0xFFE6A15C);

  /// Warm, restrained accents make the app feel intentional rather than
  /// template-generated. The mint remains available for calm/positive states.
  static const Color brandAccent = Color(0xFF91A996);
  static const Color ember = Color(0xFFC9825B);
  static const Color canvas = Color(0xFF202326);
  static const Color surface = Color(0xFF2A2E32);
  static const Color surfaceQuiet = Color(0xFF34393D);
  static const Color inkMuted = Color(0xFFAEB3B0);

  /// Reserved for the focused crisis surface so it feels distinct from the
  /// everyday charcoal canvas without introducing a bright alarm colour.
  static const Color noSmokeNavy = Color(0xFF18272B);

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: brandPrimary,
      brightness: Brightness.dark,
      primary: brandPrimary,
      secondary: brandAccent,
      surface: surface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: canvas,
        appBarTheme: const AppBarTheme(
          backgroundColor: canvas,
          foregroundColor: Color(0xFFF2EEE7),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandPrimary,
          foregroundColor: const Color(0xFF1B1610),
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFF2EEE7),
          side: const BorderSide(color: Color(0xFF596066)),
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: canvas,
        elevation: 0,
        indicatorColor: ember.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? ember
                : inkMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? ember
                : inkMuted,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
