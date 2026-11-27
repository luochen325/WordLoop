import 'package:material_ui/material_ui.dart';

class AppColors {
  static const seed = Color(0xFF5157E8);
  static const background = Color(0xFFF6F6FB);
  static const ink = Color(0xFF15162B);
  static const muted = Color(0xFF6B6E85);
  static const mint = Color(0xFF12B5A5);
  static const amber = Color(0xFFF2A33C);
  static const rose = Color(0xFFEE5570);
  static const lavender = Color(0xFF8B7CF6);
}

class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
        iconTheme: IconThemeData(color: AppColors.ink),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: AppColors.ink, height: 1.5),
        bodyMedium: TextStyle(fontSize: 14, color: AppColors.muted, height: 1.5),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: const BorderSide(color: Color(0xFFE1E2EE)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.seed.withValues(alpha: 0.12),
        height: 68,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFEDEDF5), thickness: 1),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF2F2FA),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: const TextStyle(fontSize: 13, color: AppColors.ink),
      ),
    );
  }
}
