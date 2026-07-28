import 'package:flutter/material.dart';

class AppTheme {
	/// Sampled from the logo itself, whose dominant colour is #0090B0 with a
	/// teal-to-mint gradient across the butterfly. Brightened a little from
	/// that measured value so it stays legible as a control colour on the dark
	/// navy ground. The previous accent was #00C853, a saturated grass green
	/// that appears nowhere in the artwork — buttons and progress bars read as
	/// belonging to a different app than the logo above them.
	static const Color brandPrimary = Color(0xFF00B8D4);

	/// The mint the butterfly's wing tips fade into. Secondary emphasis only.
	static const Color brandAccent = Color(0xFF3FD2B0);

	/// Unchanged: already matches the dark slate of the logo's broken chain
	/// (#002030–#103040).
	static const Color noSmokeNavy = Color(0xFF0D1B2A);

	static ThemeData get darkTheme {
		final colorScheme = ColorScheme.fromSeed(
			seedColor: brandPrimary,
			brightness: Brightness.dark,
			primary: brandPrimary,
			secondary: brandAccent,
			surface: const Color(0xFF132238),
		);

		return ThemeData(
			useMaterial3: true,
			brightness: Brightness.dark,
			colorScheme: colorScheme,
			scaffoldBackgroundColor: noSmokeNavy,
			appBarTheme: const AppBarTheme(
				backgroundColor: noSmokeNavy,
				foregroundColor: Colors.white,
				centerTitle: false,
			),
			cardTheme: CardThemeData(
				color: const Color(0xFF132238),
				elevation: 0,
				shape: RoundedRectangleBorder(
					borderRadius: BorderRadius.circular(20),
				),
			),
			elevatedButtonTheme: ElevatedButtonThemeData(
				style: ElevatedButton.styleFrom(
					backgroundColor: brandPrimary,
					foregroundColor: Colors.black,
					shape: RoundedRectangleBorder(
						borderRadius: BorderRadius.circular(16),
					),
				),
			),
			outlinedButtonTheme: OutlinedButtonThemeData(
				style: OutlinedButton.styleFrom(
					foregroundColor: Colors.white,
					side: const BorderSide(color: brandPrimary),
					shape: RoundedRectangleBorder(
						borderRadius: BorderRadius.circular(16),
					),
				),
			),
			inputDecorationTheme: InputDecorationTheme(
				filled: true,
				fillColor: const Color(0xFF132238),
				border: OutlineInputBorder(
					borderRadius: BorderRadius.circular(16),
					borderSide: BorderSide.none,
				),
			),
		);
	}
}
