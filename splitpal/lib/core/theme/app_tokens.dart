import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

@immutable
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  static const EdgeInsets pagePadding = EdgeInsets.all(lg);

  const AppSpacing._();
}

@immutable
class AppRadii {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double pill = 999;

  const AppRadii._();
}

