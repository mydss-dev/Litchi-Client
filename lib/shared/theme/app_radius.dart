import 'package:flutter/widgets.dart';

/// Corner radius tokens (§6.4).
class AppRadius {
  AppRadius._();

  static const double xs = 8; // small icons / tags
  static const double sm = 10; // menu items, selects, small buttons
  static const double md = 12; // icon boxes, normal buttons, inputs
  static const double user = 14; // user card
  static const double card = 16; // normal cards / status bar
  static const double lg = 18; // large cards / hero
  static const double window = 18; // desktop window and every overlay route
  static const double xl = 20; // connection main card / auth panel
  static const double pill = 999; // capsules / circles

  static BorderRadius all(double r) => BorderRadius.circular(r);
}
