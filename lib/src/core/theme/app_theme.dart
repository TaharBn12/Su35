import 'package:flutter/material.dart';

/// Aviation-flavoured Material 3 theme (light + dark).
///
/// Fonts are the platform defaults so the app works fully offline and renders
/// Arabic natively on Android/iOS/Windows. To bundle a specific Arabic face
/// (e.g. Cairo or IBM Plex Sans Arabic) drop the .ttf files into `assets/fonts`
/// and set `fontFamily` in [buildLight]/[buildDark].
class AppTheme {
  const AppTheme._();

  /// Deep "night flight" navy.
  static const Color navy = Color(0xFF0B1F3A);

  /// Runway / HUD green.
  static const Color hud = Color(0xFF1F7A5C);

  /// Caution amber.
  static const Color amber = Color(0xFFC77700);

  /// Warning red.
  static const Color alert = Color(0xFFC0392B);

  static const Color _lightSeed = Color(0xFF0B4F8A);
  static const Color _darkSeed = Color(0xFF7FB2E5);

  /// Palette used to let users colour their notebooks.
  static const List<Color> notebookColors = <Color>[
    Color(0xFF0B4F8A),
    Color(0xFF1F7A5C),
    Color(0xFFC77700),
    Color(0xFFC0392B),
    Color(0xFF6C4AB6),
    Color(0xFF00838F),
    Color(0xFF8D6E63),
    Color(0xFF455A64),
  ];

  /// Emoji used as notebook icons (no icon-font dependency required).
  static const List<String> notebookIcons = <String>[
    '✈️',
    '🛫',
    '🛬',
    '🛠️',
    '🧭',
    '📡',
    '📚',
    '🧯',
    '⛽',
    '🌍',
    '🪂',
    '🚁',
  ];

  static ThemeData buildLight() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _lightSeed,
      brightness: Brightness.light,
    );
    return _base(scheme).copyWith(
      scaffoldBackgroundColor: const Color(0xFFF6F8FB),
    );
  }

  static ThemeData buildDark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _darkSeed,
      brightness: Brightness.dark,
    );
    return _base(scheme).copyWith(scaffoldBackgroundColor: navy);
  }

  static ThemeData _base(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    final textTheme = _textTheme(isDark);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? navy : Colors.white,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? const Color(0xFF13294B) : Colors.white,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : const Color(0xFFE3E8F0),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF10233F) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.10)
                : const Color(0xFFD7DEE8),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.10)
                : const Color(0xFFD7DEE8),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: textTheme.titleSmall,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 44),
          textStyle: textTheme.labelLarge,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        side: BorderSide.none,
        labelStyle: textTheme.labelMedium,
        visualDensity: VisualDensity.compact,
      ),
      dividerTheme: DividerThemeData(
        space: 1,
        thickness: 1,
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : const Color(0xFFE3E8F0),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        iconColor: scheme.onSurfaceVariant,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
      ),
    );
  }

  static TextTheme _textTheme(bool isDark) {
    final color = isDark ? Colors.white : const Color(0xFF101828);
    final muted = isDark
        ? Colors.white.withValues(alpha: 0.72)
        : const Color(0xFF5A6B82);

    return TextTheme(
      displaySmall: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.25,
      ),
      headlineMedium: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.3,
      ),
      headlineSmall: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: color,
      ),
      titleLarge: TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: color,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: color, height: 1.6),
      bodyMedium: TextStyle(fontSize: 14, color: color, height: 1.6),
      bodySmall: TextStyle(fontSize: 12.5, color: muted, height: 1.5),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      labelMedium: TextStyle(fontSize: 12.5, color: muted),
      labelSmall: TextStyle(fontSize: 11.5, color: muted),
    );
  }
}
