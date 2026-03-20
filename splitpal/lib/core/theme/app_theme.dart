import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'app_tokens.dart';
import 'app_typography.dart';

@immutable
class AppTheme {
  static ThemeData light() {
    return _buildTheme(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      surfaceColor: Colors.white,
      colorScheme: _buildColorScheme(
        brightness: Brightness.light,
        surface: Colors.white,
        onSurface: AppColors.midnightBlue,
        outline: AppColors.silver,
        surfaceContainerLowest: const Color(0xFFF8FAFC),
        surfaceContainerLow: const Color(0xFFF1F5F9),
        surfaceContainer: const Color(0xFFE2E8F0),
        surfaceContainerHigh: const Color(0xFFCBD5E1),
        surfaceContainerHighest: const Color(0xFFB8C4D2),
        onSurfaceVariant: AppColors.asbestos,
        outlineVariant: const Color(0xFFD2D8DE),
      ),
    );
  }

  static ThemeData dark() {
    return _buildTheme(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0B1220),
      surfaceColor: const Color(0xFF111827),
      colorScheme: _buildColorScheme(
        brightness: Brightness.dark,
        surface: const Color(0xFF111827),
        onSurface: const Color(0xFFF8FAFC),
        outline: const Color(0xFF334155),
        surfaceContainerLowest: const Color(0xFF0F172A),
        surfaceContainerLow: const Color(0xFF111827),
        surfaceContainer: const Color(0xFF1E293B),
        surfaceContainerHigh: const Color(0xFF273449),
        surfaceContainerHighest: const Color(0xFF334155),
        onSurfaceVariant: const Color(0xFFCBD5E1),
        outlineVariant: const Color(0xFF334155),
      ),
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required ColorScheme colorScheme,
    required Color scaffoldBackgroundColor,
    required Color surfaceColor,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackgroundColor,
      fontFamily: 'BeVietnamPro',
    );

    final textTheme = AppTypography.build(
      base: base.textTheme,
      colorScheme: colorScheme,
    );

    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.md),
      side: BorderSide(
        color: colorScheme.outlineVariant.withAlpha((0.6 * 255).round()),
      ),
    );

    return base.copyWith(
      textTheme: textTheme,
      dividerColor: colorScheme.outlineVariant.withAlpha((0.6 * 255).round()),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceColor,
        elevation: 0,
        indicatorColor: colorScheme.primary.withAlpha(28),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
            size: 24,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            color: selected
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          );
        }),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceColor,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleMedium,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        indicatorColor: colorScheme.primary,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor:
            colorScheme.outlineVariant.withAlpha((0.6 * 255).round()),
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: cardShape,
        color: colorScheme.surface,
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: brightness == Brightness.dark
            ? colorScheme.surfaceContainerHigh
            : colorScheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: brightness == Brightness.dark
            ? colorScheme.surfaceContainerHighest
            : colorScheme.onSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: brightness == Brightness.dark
              ? colorScheme.onSurface
              : colorScheme.surface,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.surfaceContainerHigh;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary
                .withAlpha((0.35 * 255).round());
          }
          return colorScheme.outlineVariant;
        }),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.onPrimary;
          }
          return colorScheme.outline;
        }),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
        ),
      ),
    );
  }

  static ColorScheme _buildColorScheme({
    required Brightness brightness,
    required Color surface,
    required Color onSurface,
    required Color outline,
    required Color surfaceContainerLowest,
    required Color surfaceContainerLow,
    required Color surfaceContainer,
    required Color surfaceContainerHigh,
    required Color surfaceContainerHighest,
    required Color onSurfaceVariant,
    required Color outlineVariant,
  }) {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: AppColors.pomegranate,
      brightness: brightness,
    );

    return baseScheme.copyWith(
      primary: AppColors.pomegranate,
      onPrimary: Colors.white,
      secondary: AppColors.alizarin,
      onSecondary: Colors.white,
      tertiary: brightness == Brightness.dark
          ? const Color(0xFF22C55E)
          : const Color(0xFF16A34A),
      onTertiary: Colors.white,
      tertiaryContainer: brightness == Brightness.dark
          ? const Color(0xFF14532D)
          : const Color(0xFFDCFCE7),
      onTertiaryContainer: brightness == Brightness.dark
          ? const Color(0xFFDCFCE7)
          : const Color(0xFF14532D),
      error: baseScheme.error,
      onError: baseScheme.onError,
      surface: surface,
      onSurface: onSurface,
      outline: outline,
      surfaceContainerLowest: surfaceContainerLowest,
      surfaceContainerLow: surfaceContainerLow,
      surfaceContainer: surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh,
      surfaceContainerHighest: surfaceContainerHighest,
      onSurfaceVariant: onSurfaceVariant,
      outlineVariant: outlineVariant,
    );
  }

  const AppTheme._();
}
