import 'package:flutter/animation.dart';

/// Motion language for state feedback and route-level surfaces.
class AppMotion {
  AppMotion._();

  static const Duration fast = Duration(milliseconds: 120);
  static const Duration normal = Duration(milliseconds: 180);
  static const Duration slow = Duration(milliseconds: 240);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve standard = Curves.easeInOutCubic;
}
