// lib/src/core/theme/main_theme.dart
//
// FarmApp Material 3 theme.
//
// Color tokens, type ramp, spacing, and component conventions are defined in
// `CLAUDE.md` (Design Context) and `.impeccable.md`. The brand greens are set
// explicitly via `ColorScheme.light(...)` rather than `ColorScheme.fromSeed`
// so the values stay exact across the surface roles.
//
// Numbers (size >= 14) use `FontFeature.tabularFigures()` so counts and dates
// align as columns.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand color tokens.
///
/// These constants are kept for backwards compatibility with existing screens
/// that reference them directly. New code should read colors from
/// `Theme.of(context).colorScheme` so the tokens stay consistent.
class AppColors {
  @Deprecated('Use Theme.of(context).colorScheme.primary')
  static const Color primaryGreen = Color(0xFF2E7D32);

  @Deprecated('Use Theme.of(context).colorScheme.secondary')
  static const Color darkGreen = Color(0xFF1A3A3A);

  @Deprecated('Use Theme.of(context).colorScheme.surfaceContainer')
  static const Color background = Color(0xFFF1F3F5);

  @Deprecated('Use Theme.of(context).colorScheme.surface')
  static const Color cardBackground = Color(0xFFFFFFFF);

  @Deprecated('Use Theme.of(context).colorScheme.onSurface')
  static const Color textDark = Color(0xFF1B1F1A);

  @Deprecated('Use Theme.of(context).colorScheme.onSurfaceVariant')
  static const Color textLight = Color(0xFF5A625C);

  @Deprecated('Use Theme.of(context).colorScheme.surface')
  static const Color inputFill = Color(0xFFFFFFFF);

  @Deprecated('Use Theme.of(context).colorScheme.tertiary')
  static const Color accentYellow = Color(0xFFE8A317);
}

/// Explicit M3 color scheme — every brand-relevant slot is assigned.
///
/// `surfaceTint` is wired to `primary` so M3 elevation overlays read green
/// rather than a generated lavender.
const ColorScheme _scheme = ColorScheme.light(
  primary: Color(0xFF2E7D32),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFC8E6C9),
  onPrimaryContainer: Color(0xFF102510),
  secondary: Color(0xFF1A3A3A),
  onSecondary: Color(0xFFFFFFFF),
  tertiary: Color(0xFFE8A317),
  onTertiary: Color(0xFF1B1F1A),
  error: Color(0xFFC0392B),
  onError: Color(0xFFFFFFFF),
  surface: Color(0xFFFFFFFF),
  onSurface: Color(0xFF1B1F1A),
  surfaceContainer: Color(0xFFF1F3F5),
  surfaceContainerHigh: Color(0xFFE9ECEF),
  onSurfaceVariant: Color(0xFF5A625C),
  outline: Color(0xFFD4D6D8),
  outlineVariant: Color(0xFFE0E2E4),
  surfaceTint: Color(0xFF2E7D32),
);

const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

TextTheme _buildTextTheme(ColorScheme scheme) {
  return TextTheme(
    headlineLarge: GoogleFonts.poppins(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      color: scheme.onSurface,
      fontFeatures: _tabular,
    ),
    headlineMedium: GoogleFonts.poppins(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.25,
      color: scheme.onSurface,
      fontFeatures: _tabular,
    ),
    headlineSmall: GoogleFonts.poppins(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: scheme.onSurface,
      fontFeatures: _tabular,
    ),
    titleMedium: GoogleFonts.poppins(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: scheme.onSurface,
      fontFeatures: _tabular,
    ),
    bodyLarge: GoogleFonts.poppins(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: scheme.onSurface,
      fontFeatures: _tabular,
    ),
    bodyMedium: GoogleFonts.poppins(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: scheme.onSurfaceVariant,
      fontFeatures: _tabular,
    ),
    labelLarge: GoogleFonts.poppins(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      color: scheme.onSurface,
      fontFeatures: _tabular,
    ),
    labelMedium: GoogleFonts.poppins(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.2,
      color: scheme.onSurfaceVariant,
    ),
  );
}

/// FarmApp's master Material 3 theme. Light only for v1.
ThemeData _buildTheme() {
  const scheme = _scheme;
  final textTheme = _buildTextTheme(scheme);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surfaceContainer,
    textTheme: textTheme,
    primaryColor: scheme.primary,

    // Cards feel like physical index cards — soft elevation, generous radius.
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      surfaceTintColor: scheme.surfaceTint,
      margin: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),

    // Primary CTA: pill, dark accent green, white text.
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.secondary,
        foregroundColor: scheme.onSecondary,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: const StadiumBorder(),
        textStyle: textTheme.labelLarge,
        elevation: 0,
      ),
    ),

    // M3 filled button: pill, brand green.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: const StadiumBorder(),
        textStyle: textTheme.labelLarge,
      ),
    ),

    // Text button: brand-green text, no shape coercion.
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.primary,
        textStyle: textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),

    // Secondary in-card actions: lower-radius rectangle, brand-green outline.
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.primary,
        side: BorderSide(color: scheme.primary, width: 1),
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: textTheme.labelLarge,
      ),
    ),

    // Filled input style — no border by default, brand-green focus ring.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainer,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.error, width: 1.5),
      ),
      labelStyle: textTheme.bodyMedium,
      floatingLabelStyle: textTheme.bodyMedium?.copyWith(
        color: scheme.primary,
      ),
      hintStyle:
          textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      floatingLabelBehavior: FloatingLabelBehavior.never,
    ),

    // Chips: 32 dp tall via padding, soft pill, primaryContainer when selected.
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surface,
      selectedColor: scheme.primaryContainer,
      disabledColor: scheme.surfaceContainerHigh,
      labelStyle: textTheme.labelMedium?.copyWith(color: scheme.onSurface),
      secondaryLabelStyle:
          textTheme.labelMedium?.copyWith(color: scheme.onPrimaryContainer),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: scheme.outline),
      ),
      side: BorderSide(color: scheme.outline),
      showCheckmark: false,
      elevation: 0,
      pressElevation: 0,
    ),

    // AppBar blends with scaffold — no awkward dark stripe against light content.
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surfaceContainer,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: scheme.onSurface),
      actionsIconTheme: IconThemeData(color: scheme.onSurface),
      titleTextStyle: textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
      ),
      centerTitle: false,
    ),

    // iOS niceties — page transitions per platform.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.windows: ZoomPageTransitionsBuilder(),
        TargetPlatform.linux: ZoomPageTransitionsBuilder(),
        TargetPlatform.fuchsia: ZoomPageTransitionsBuilder(),
      },
    ),

    listTileTheme: ListTileThemeData(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      iconColor: scheme.onSurfaceVariant,
      textColor: scheme.onSurface,
      titleTextStyle: textTheme.titleMedium,
      subtitleTextStyle: textTheme.bodyMedium,
    ),

    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      space: 1,
      thickness: 0.5,
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: scheme.onSurface,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: scheme.surface),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
    ),

    // Note: this Flutter version's `FloatingActionButtonThemeData` exposes a
    // single `shape` slot, so the extended FAB inherits the framework's
    // default stadium shape automatically — we only need to set the round
    // shape here.
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 2,
      focusElevation: 3,
      hoverElevation: 3,
      highlightElevation: 4,
      shape: const CircleBorder(),
      extendedTextStyle: textTheme.labelLarge?.copyWith(
        color: scheme.onPrimary,
      ),
    ),

    tabBarTheme: TabBarThemeData(
      labelColor: scheme.primary,
      unselectedLabelColor: scheme.onSurfaceVariant,
      indicatorColor: scheme.primary,
      dividerColor: scheme.outlineVariant,
      labelStyle: textTheme.labelLarge,
      unselectedLabelStyle: textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

/// FarmApp's master Material 3 theme.
final ThemeData mainTheme = _buildTheme();
