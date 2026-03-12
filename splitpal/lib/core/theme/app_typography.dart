import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

@immutable
class AppTypography {
  static TextTheme build({
    required TextTheme base,
    required ColorScheme colorScheme,
  }) {
    // Keep Material 3 sizing but strengthen hierarchy for a "finance/utility"
    // product: headings are heavier, body is a bit more airy.
    final next = base.copyWith(
      titleLarge: base.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
      ),
      titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      labelMedium: base.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: base.bodyLarge?.copyWith(height: 1.25),
      bodyMedium: base.bodyMedium?.copyWith(height: 1.3),
      bodySmall: base.bodySmall?.copyWith(height: 1.3),
    );

    return next.apply(
      fontFamily: 'BeVietnamPro',
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    );
  }

  const AppTypography._();
}

