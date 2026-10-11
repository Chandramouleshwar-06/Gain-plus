import 'package:flutter/material.dart';

/// "Bold & Sporty" palette: near-black grounds, one lime accent.
class AppColors {
  static const bg = Color(0xFF0B0B0C);
  static const surface = Color(0xFF161618);
  static const surfaceHigh = Color(0xFF202023);
  static const border = Color(0xFF2A2A2E);
  static const navBar = Color(0xFF131315);

  static const text = Color(0xFFF4F4F1);
  static const textMuted = Color(0xFF9A9A96);
  static const textFaint = Color(0xFF6E6E6A);

  /// The accent. Always put [onLime] text on it, never white.
  static const lime = Color(0xFFC8F031);
  static const onLime = Color(0xFF0B0B0C);

  /// Streaks and personal records.
  static const orange = Color(0xFFFF8A3D);
  static const danger = Color(0xFFFF6B6B);
}

class AppFonts {
  /// Headlines and big numbers.
  static const display = 'BarlowCondensed';
  static const body = 'Barlow';
}

class AppText {
  /// Big condensed headline, e.g. "LET'S GO" or the workout timer.
  static TextStyle display(double size, {Color color = AppColors.text, FontWeight weight = FontWeight.w800}) =>
      TextStyle(
        fontFamily: AppFonts.display,
        fontSize: size,
        fontWeight: weight,
        height: 1.0,
        letterSpacing: 0.2,
        color: color,
      );

  /// Small spaced-out caps label, e.g. "TODAY'S SESSION".
  static const eyebrow = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
    color: AppColors.textMuted,
  );

  static const body = TextStyle(fontFamily: AppFonts.body, fontSize: 15, color: AppColors.text);
  static const muted = TextStyle(fontFamily: AppFonts.body, fontSize: 14, color: AppColors.textMuted);
  static const strong = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.text,
  );

  /// Tabular digits so timers and counters don't jitter.
  static const tabular = [FontFeature.tabularFigures()];
}

class AppRadius {
  static const card = 20.0;
  static const hero = 24.0;
  static const field = 14.0;
}

class AppTheme {
  static final ThemeData darkTheme = _build();

  static ThemeData _build() {
    const scheme = ColorScheme.dark(
      primary: AppColors.lime,
      onPrimary: AppColors.onLime,
      secondary: AppColors.orange,
      onSecondary: AppColors.onLime,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      surfaceContainerHighest: AppColors.surfaceHigh,
      onSurfaceVariant: AppColors.textMuted,
      outline: AppColors.border,
      error: AppColors.danger,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bg,
      fontFamily: AppFonts.body,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        headlineLarge: AppText.display(36),
        headlineMedium: AppText.display(30),
        headlineSmall: AppText.display(24, weight: FontWeight.w700),
        titleLarge: const TextStyle(fontFamily: AppFonts.body, fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text),
        titleMedium: const TextStyle(fontFamily: AppFonts.body, fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text),
        bodyLarge: const TextStyle(fontFamily: AppFonts.body, fontSize: 16, color: AppColors.text),
        bodyMedium: const TextStyle(fontFamily: AppFonts.body, fontSize: 15, color: AppColors.text),
        bodySmall: const TextStyle(fontFamily: AppFonts.body, fontSize: 14, color: AppColors.textMuted),
        labelLarge: const TextStyle(fontFamily: AppFonts.body, fontSize: 15, fontWeight: FontWeight.w700),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceHigh,
        hintStyle: const TextStyle(color: AppColors.textFaint),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: const BorderSide(color: AppColors.lime, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.lime,
          foregroundColor: AppColors.onLime,
          elevation: 0,
          minimumSize: const Size(64, 48),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontFamily: AppFonts.body, fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.lime,
          minimumSize: const Size(44, 44),
          textStyle: const TextStyle(fontFamily: AppFonts.body, fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.lime,
        foregroundColor: AppColors.onLime,
        shape: StadiumBorder(),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.hero)),
        titleTextStyle: AppText.display(24, weight: FontWeight.w700),
        contentTextStyle: const TextStyle(fontFamily: AppFonts.body, fontSize: 15, color: AppColors.textMuted),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        showDragHandle: true,
        dragHandleColor: AppColors.border,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.hero)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceHigh,
        contentTextStyle: const TextStyle(fontFamily: AppFonts.body, fontSize: 15, color: AppColors.text),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.field)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceHigh,
        selectedColor: AppColors.lime,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        labelStyle: const TextStyle(fontFamily: AppFonts.body, fontSize: 14, fontWeight: FontWeight.w600),
        secondaryLabelStyle: const TextStyle(color: AppColors.onLime, fontWeight: FontWeight.w700),
        checkmarkColor: AppColors.onLime,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.onLime,
        unselectedLabelColor: AppColors.textMuted,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: TextStyle(fontFamily: AppFonts.body, fontSize: 15, fontWeight: FontWeight.w700),
        unselectedLabelStyle: TextStyle(fontFamily: AppFonts.body, fontSize: 15, fontWeight: FontWeight.w600),
        indicator: ShapeDecoration(color: AppColors.lime, shape: StadiumBorder()),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1, space: 1),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textMuted,
        textColor: AppColors.text,
        contentPadding: EdgeInsets.symmetric(horizontal: 20),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? AppColors.onLime : AppColors.textMuted),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? AppColors.lime : AppColors.surfaceHigh),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      timePickerTheme: const TimePickerThemeData(backgroundColor: AppColors.surface),
      datePickerTheme: const DatePickerThemeData(backgroundColor: AppColors.surface),
    );
  }
}
