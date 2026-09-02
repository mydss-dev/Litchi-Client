import 'package:flutter/widgets.dart';

/// Corner-radius tokens.
///
/// Controls stay tighter than cards so the desktop UI feels precise instead
/// of overly soft/mobile-like. Large hero/window surfaces keep extra radius.
class AppRadius {
  AppRadius._();

  static const double xs = 6; // tags / tiny badges
  static const double sm = 8; // compact controls / menu items
  static const double md = 10; // buttons / inputs / icon boxes
  static const double user = 12; // user / compact cards
  static const double card = 12; // standard cards
  static const double lg = 16; // large cards / dialogs
  static const double window = 18; // desktop window chrome
  static const double xl = 18; // hero/auth surfaces
  static const double pill = 999; // capsules / circles

  static BorderRadius all(double r) => BorderRadius.circular(r);
}
