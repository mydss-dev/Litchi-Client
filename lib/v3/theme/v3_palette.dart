import 'package:flutter/material.dart';

/// Litchi's visual language: editorial black, lychee red, and citrus signal.
/// Light and dark palettes are composed independently, not simply inverted.
@immutable
class V3Palette {
  const V3Palette({
    required this.canvas,
    required this.surface,
    required this.surfaceRaised,
    required this.night,
    required this.hero,
    required this.ink,
    required this.inkMuted,
    required this.line,
    required this.lychee,
    required this.lycheeSoft,
    required this.citrus,
    required this.aqua,
    required this.success,
    required this.warning,
    required this.danger,
    required this.lycheeInk,
    required this.successInk,
    required this.warningInk,
    required this.dangerInk,
    required this.aquaInk,
    required this.onLychee,
    required this.onDanger,
  });

  final Color canvas;
  final Color surface;
  final Color surfaceRaised;

  /// Background for the large "hero" panels — the connect workspace, the login
  /// brand block, the sidebar.
  ///
  /// These used to be [night], which is near-black in *both* modes and turned
  /// every one of them into a black slab on an otherwise light screen. [night]
  /// is now only a *foreground* colour (something drawn on top of [citrus]);
  /// this is the surface behind it.
  final Color hero;
  final Color night;
  final Color ink;
  final Color inkMuted;
  final Color line;
  final Color lychee;
  final Color lycheeSoft;
  final Color citrus;
  final Color aqua;
  final Color success;
  final Color warning;
  final Color danger;

  /// Text-safe variants of the semantic colors.
  ///
  /// The four colors above are tuned as fills and icons: on a light ground they
  /// sit between 3.2:1 and 4.8:1, which clears the 3:1 WCAG asks of graphical
  /// objects but not the 4.5:1 it asks of body text. Small colored labels and
  /// error messages therefore use these darker inks, which clear 4.5:1 against
  /// every light surface. Dark mode already exceeds the ratio, so there the inks
  /// are simply the base colors.
  final Color lycheeInk;
  final Color successInk;
  final Color warningInk;
  final Color dangerInk;

  /// The one ink for [aqua], which the gauge strip needed to complete its
  /// four-accent spread. Light mode darkens the decorative aqua to a deep
  /// teal (~5:1 on [surface]); dark mode is the base aqua itself (10:1).
  final Color aquaInk;

  /// Foregrounds drawn on top of solid [lychee] fills (primary buttons, the
  /// connect orb, the brand avatar). White fails here: light mode sits at
  /// 3.3:1 and dark mode at 2.8:1 — below even the 3:1 graphical ask — while
  /// [night] clears 4.5:1 in both modes (5.1:1 light, 6.7:1 dark). This is the
  /// same pairing the brand mark already uses on its citrus tile.
  final Color onLychee;

  /// Foreground on solid [danger] fills. White passes on the darker light-mode
  /// red (4.8:1) but sinks to 2.6:1 on the lighter dark-mode red, where [night]
  /// reads at 6.5:1.
  final Color onDanger;

  static const light = V3Palette(
    // Four tiers, darkest to lightest: canvas → hero → surfaceRaised → surface.
    //
    // Light mode used to run canvas #F3F4F0 under surface #FFFFFF, which is a
    // 3% difference — the background was there, but nothing on screen showed
    // it, so every page read as one flat white sheet with no depth. Dark mode
    // never had that problem (canvas #0C1010 and card #151B1A are obvious
    // steps), so these four are spaced to mirror it: a sage-green ground, a
    // near-white card sitting clearly above it, and a hero panel a shade below
    // the ground rather than above it, which is the direction dark mode uses
    // for its own hero.
    //
    // Pure white no longer appears in light mode at all. The one exception is
    // the QR pad in the payment flow, which scanners want white and which
    // therefore hard-codes it rather than reading a token.
    canvas: Color(0xFFE7EBE3),
    surface: Color(0xFFFBFCF9),
    surfaceRaised: Color(0xFFF0F2EC),
    hero: Color(0xFFDFE3DA),
    night: Color(0xFF121515),
    ink: Color(0xFF121515),
    // Darkened from #68716F (4.17:1 on `surfaceRaised`, below AA for the
    // segmented-control labels that sit on that track) and again from #636B69
    // when `hero` darkened underneath it — see `hero` above.
    inkMuted: Color(0xFF5C6462),
    line: Color(0xFFCBD2CB),
    lychee: Color(0xFFF25472),
    lycheeSoft: Color(0xFFFFE3E8),
    citrus: Color(0xFFD7F267),
    aqua: Color(0xFF70D7D5),
    success: Color(0xFF249A6A),
    // Darkened from #C68122, which was 2.90:1 on `canvas` — below the 3:1 WCAG
    // asks of an icon or UI shape drawn on that ground.
    warning: Color(0xFFBA771C),
    danger: Color(0xFFCC3F57),
    // Keep text safe even on a green-tinted hero: #177045 only reached 4.18:1
    // after the 12% success tint was composited onto the darker hero surface.
    lycheeInk: Color(0xFFB32747),
    successInk: Color(0xFF11613A),
    warningInk: Color(0xFF8A5000),
    dangerInk: Color(0xFFB02E45),
    aquaInk: Color(0xFF0B6F6C),
    onLychee: Color(0xFF121515),
    // The one deliberate pure white in light mode besides the QR pad: the
    // danger red is dark enough that white clears AA, while night does not
    // (3.6:1). See the QR note under `canvas` above.
    onDanger: Color(0xFFFFFFFF),
  );

  static const dark = V3Palette(
    canvas: Color(0xFF0C1010),
    surface: Color(0xFF151B1A),
    surfaceRaised: Color(0xFF202826),
    // Dark mode keeps the near-black it always had; only light mode moves.
    hero: Color(0xFF080B0A),
    night: Color(0xFF080B0A),
    ink: Color(0xFFF0F5F0),
    inkMuted: Color(0xFF9BA8A3),
    line: Color(0xFF2B3834),
    lychee: Color(0xFFFF6683),
    lycheeSoft: Color(0xFF3A2027),
    citrus: Color(0xFFD7F267),
    aqua: Color(0xFF79E0DC),
    success: Color(0xFF57D39A),
    warning: Color(0xFFF1BD59),
    danger: Color(0xFFFF7188),
    lycheeInk: Color(0xFFFF6683),
    successInk: Color(0xFF57D39A),
    warningInk: Color(0xFFF1BD59),
    dangerInk: Color(0xFFFF7188),
    aquaInk: Color(0xFF79E0DC),
    onLychee: Color(0xFF080B0A),
    onDanger: Color(0xFF080B0A),
  );

  static V3Palette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// Corner radius tiers. Every box draws one of these four curves instead of
/// inventing its own — the sweep that collapsed nineteen ad-hoc values into
/// them deliberately keeps the app a little squarer so the tiers hold:
///
/// * [control] — chips, tags, tooltips, mini icon tiles.
/// * [field] — text inputs, every button, segmented tracks, small tiles.
/// * [card] — list rows, standard cards, inner panels. This is the curve a
///   [V3Panel] draws unless told otherwise.
/// * [panel] — page-level panels, dialogs and sheets.
///
/// Two non-tier values remain literal on purpose: the 2dp progress hairline
/// and the 99 pill.
abstract final class V3Radius {
  static const double control = 10;
  static const double field = 12;
  static const double card = 16;
  static const double panel = 24;
}

class V3Theme {
  const V3Theme._();

  static ThemeData light() => _build(Brightness.light, V3Palette.light);

  static ThemeData dark() => _build(Brightness.dark, V3Palette.dark);

  static ThemeData _build(Brightness brightness, V3Palette p) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: p.lychee,
      onPrimary: p.onLychee,
      // Green is reserved for measured/confirmed status, never selection.
      // Material controls that fall back to secondary must still select pink.
      secondary: p.lychee,
      onSecondary: p.night,
      error: p.danger,
      onError: p.onDanger,
      surface: p.surface,
      onSurface: p.ink,
      outline: p.line,
      surfaceContainerHighest: p.surfaceRaised,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.canvas,
      fontFamily: 'Segoe UI',
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 36,
          height: 1.0,
          fontWeight: FontWeight.w800,
          color: p.ink,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          height: 1.05,
          fontWeight: FontWeight.w800,
          color: p.ink,
        ),
        headlineLarge: TextStyle(
          fontSize: 22,
          height: 1.1,
          fontWeight: FontWeight.w700,
          color: p.ink,
        ),
        headlineMedium: TextStyle(
          fontSize: 18,
          height: 1.2,
          fontWeight: FontWeight.w700,
          color: p.ink,
        ),
        titleLarge: TextStyle(
          fontSize: 16,
          height: 1.2,
          fontWeight: FontWeight.w700,
          color: p.ink,
        ),
        titleMedium: TextStyle(
          fontSize: 14,
          height: 1.25,
          fontWeight: FontWeight.w600,
          color: p.ink,
        ),
        bodyLarge: TextStyle(fontSize: 14, height: 1.45, color: p.ink),
        bodyMedium: TextStyle(fontSize: 13, height: 1.4, color: p.ink),
        bodySmall: TextStyle(fontSize: 12, height: 1.4, color: p.inkMuted),
        labelLarge: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: p.ink,
        ),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: p.inkMuted,
        ),
      ),
      dividerColor: p.line,
      // Keep a quiet but visible press state without a spreading ripple.
      splashFactory: NoSplash.splashFactory,
      highlightColor: p.ink.withValues(alpha: 0.10),
      hoverColor: p.ink.withValues(alpha: 0.04),
      // Selection follows the cycle chooser: a soft pink ground, dark/light
      // palette-safe lychee ink, and a matching border. Never white on lime.
      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        selectedColor: p.lycheeSoft,
        side: BorderSide(color: p.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(V3Radius.control)),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: p.ink,
        ),
        secondaryLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: p.lycheeInk,
        ),
        checkmarkColor: p.lycheeInk,
      ),
      // The order filter used Material's implicit SegmentedButton skin while
      // the traffic period picker and shop cycle picker supplied their own.
      // One global fallback prevents new segmented controls regressing to green.
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? p.lycheeSoft : p.surfaceRaised),
          foregroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? p.lycheeInk : p.ink),
          side: WidgetStateProperty.resolveWith((states) => BorderSide(
            color: states.contains(WidgetState.selected) ? p.lychee : p.line,
            width: states.contains(WidgetState.selected) ? 1.5 : 1)),
          iconColor: WidgetStatePropertyAll(p.lycheeInk),
          textStyle: const WidgetStatePropertyAll(TextStyle(
            fontWeight: FontWeight.w700, fontSize: 12)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(V3Radius.field),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(V3Radius.field),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceRaised,
        hintStyle: TextStyle(color: p.inkMuted, fontSize: 13),
        prefixIconColor: p.inkMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(V3Radius.field),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(V3Radius.field),
          borderSide: BorderSide(color: p.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(V3Radius.field),
          borderSide: BorderSide(color: p.lychee, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.ink,
          borderRadius: BorderRadius.circular(V3Radius.control),
        ),
        textStyle: TextStyle(color: p.surface, fontSize: 11),
      ),
    );
  }
}
