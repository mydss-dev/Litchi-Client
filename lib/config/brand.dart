import 'package:flutter/widgets.dart';

/// Compile-time brand configuration — all values come from --dart-define.
///
/// Build a white-label version:
///   flutter build windows --release
///     --dart-define=APP_NAME="MyVPN"
///     --dart-define=APP_SUBTITLE="Fast & Secure"
///     --dart-define=LOGO_LETTER="M"
///     --dart-define=BRAND_COLOR_START="0F766E"
///     --dart-define=BRAND_COLOR_END="7C3AED"
abstract final class BrandConfig {
  // ── Text ──────────────────────────────────────────────────────────────────

  /// Primary brand name shown in sidebar, tray tooltip, window title, etc.
  static const appName = String.fromEnvironment(
    'APP_NAME',
    defaultValue: 'Litchi',
  );

  /// One-line tagline shown under the logo in sidebar and auth panel.
  static const appSubtitle = String.fromEnvironment(
    'APP_SUBTITLE',
    defaultValue: 'Network Client',
  );

  /// Letter shown in the gradient-fallback logo when the SVG is missing.
  static const logoLetter = String.fromEnvironment(
    'LOGO_LETTER',
    defaultValue: 'L',
  );

  // ── Colors ────────────────────────────────────────────────────────────────

  /// Gradient start — 6-digit hex without '#', e.g. "2563EB".
  static const _startHex = String.fromEnvironment(
    'BRAND_COLOR_START',
    defaultValue: '2563EB',
  );

  /// Gradient end — 6-digit hex without '#', e.g. "7C3AED".
  static const _endHex = String.fromEnvironment(
    'BRAND_COLOR_END',
    defaultValue: '7C3AED',
  );

  static Color get brandStart => _hex(_startHex);
  static Color get brandEnd   => _hex(_endHex);

  static LinearGradient get brandGradient => LinearGradient(
    colors: [brandStart, brandEnd],
  );

  static Color _hex(String h) =>
    Color(int.parse('FF${h.replaceAll('#', '')}', radix: 16));
}
