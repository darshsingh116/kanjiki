import 'package:flutter/material.dart';

class AppColors {
  // Backgrounds & Surfaces
  static const Color bgDark = Color(0xFF0C0D14);
  static const Color surface = Color(0xFF151722);
  static const Color surfaceElevated = Color(0xFF1E2130);
  static const Color surfaceHighlight = Color(0xFF282C40);

  // Borders & Dividers
  static const Color border = Color(0xFF2C3248);
  static const Color borderLight = Color(0xFF3E4663);
  static const Color borderActive = Color(0xFF7A68FF);

  // Vibrant Accents (Dark Neobrutalism)
  static const Color primary = Color(0xFF705DF2);
  static const Color primaryLight = Color(0xFF8E7EFE);
  static const Color primaryDark = Color(0xFF5642DE);

  static const Color cyan = Color(0xFF06B6D4);
  static const Color green = Color(0xFF10B981);
  static const Color amber = Color(0xFFF59E0B);
  static const Color red = Color(0xFFEF4444);
  static const Color pink = Color(0xFFEC4899);
  static const Color purple = Color(0xFFA855F7);

  // Anki SRS Colors
  static const Color srsNew = Color(0xFF0284C7); // Blue
  static const Color srsLearn = Color(0xFFEF4444); // Red
  static const Color srsReview = Color(0xFF10B981); // Green
  static const Color srsEasy = Color(0xFF06B6D4); // Cyan

  // Text Colors
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
}

class AppStyles {
  // Tactile Neobrutalist Shadow
  static List<BoxShadow> neoShadow({Color color = Colors.black, double offset = 3}) {
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.8),
        offset: Offset(offset, offset),
        blurRadius: 0,
      )
    ];
  }

  // Card Decoration
  static BoxDecoration neoCardDecoration({
    Color bg = AppColors.surface,
    Color borderColor = AppColors.border,
    double radius = 14,
    bool withShadow = true,
  }) {
    return BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor, width: 1.5),
      boxShadow: withShadow ? neoShadow() : null,
    );
  }

  // Button Decoration / Style
  static ButtonStyle neoButtonStyle({
    required Color bg,
    Color fg = Colors.white,
    Color borderColor = Colors.black,
    double radius = 12,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  }) {
    return ElevatedButton.styleFrom(
      backgroundColor: bg,
      foregroundColor: fg,
      padding: padding,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: borderColor, width: 1.5),
      ),
    );
  }
}

ThemeData buildAppTheme() {
  return ThemeData.dark(useMaterial3: true).copyWith(
    scaffoldBackgroundColor: AppColors.bgDark,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.cyan,
      surface: AppColors.surface,
      error: AppColors.red,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bgDark,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
      iconTheme: IconThemeData(color: AppColors.textPrimary),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border, width: 1.5),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 1.5),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: AppColors.border, width: 1.5),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1.5,
      space: 1.5,
    ),
  );
}
