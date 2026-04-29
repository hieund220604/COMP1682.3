import 'package:flutter/material.dart';

// App Colors — Brand: Red-Orange
class AppColors {
  // ── Brand Red-Orange ──────────────────────────────────────────────────────
  static const Color brand        = Color(0xFFE8472A); // Primary brand
  static const Color brandLight   = Color(0xFFFF8A72); // Lighter shade (hover/accent)
  static const Color brandDark    = Color(0xFFC23A20); // Darker shade (pressed)
  static const Color brandSurface = Color(0xFFFFEDE9); // Very light tint (backgrounds)

  // Legacy aliases kept for backwards compat
  static const Color alizarin    = brand;
  static const Color pomegranate = brandDark;

  // ── Neutrals ──────────────────────────────────────────────────────────────
  static const Color clouds      = Color(0xFFECF0F1);
  static const Color silver      = Color(0xFFBDC3C7);
  static const Color concrete    = Color(0xFF95A5A6);
  static const Color asbestos    = Color(0xFF7F8C8D);
  static const Color charcoal    = Color(0xFF333333);
  static const Color midnightBlue = Color(0xFF2C3E50);

  // ── Semantic ──────────────────────────────────────────────────────────────
  static const Color primary      = brand;
  static const Color primaryHover = brandDark;
  static const Color surface      = Colors.white;
  static const Color background   = Color(0xFFFFF8F6); // Warm white tinted
}
