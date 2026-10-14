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
    required this.hairline,
    required this.cardGradient,
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
    required this.shadows,
  });

  final Color canvas;
  final Color surface;
  final Color surfaceRaised;

  /// Background for the large "hero" panels — the connect workspace, the login
  /// brand block, the sidebar.
  ///
  /// [night] is a *foreground* colour; this is the surface behind it.
  final Color hero;
  final Color night;
  final Color ink;
  final Color inkMuted;
  final Color line;

  /// The quiet 1px outline that rides along with [shadows] on panels and
  /// cards. Layering needs both at once — a hairline alone reads as a
  /// wireframe, a shadow alone reads as nothing — which is the recipe DLSS5
  /// Swapper's "Aurora" theme uses in both modes: light draws
  /// `--hair: rgba(12,22,40,.10)` under a 35% blue-black drop shadow, dark
  /// draws `--hair: rgba(255,255,255,.09)` under its deep shadow, and Fluent
  /// and Ant cards agree (white ~7% stroke in dark).
  final Color hairline;
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

  /// Soft ambient shadows for floating surfaces (panels, the rail, dialogs).
  ///
  /// Both modes pair these with the [hairline] outline — layering needs line
  /// and light together; either alone reads flat or wireframe-y. Dark mode
  /// takes a deeper, longer two-layer shadow (DLSS5's
  /// `0 24px 60px -24px rgba(0,0,0,.85)` is the reference) so the blue-black
  /// canvas reads as real depth under the cards.
  final List<BoxShadow> shadows;

  /// The two-step vertical wash a workspace card fills itself with: a touch
  /// brighter at the top, a touch sunk at the bottom, straddling [surface].
  /// Flat fills are how cards disappear into sheets; DLSS5's glass cards run
  /// `linear-gradient(180deg, var(--panel), var(--panel-2))` for the same
  /// quiet volume, and "light from above" is the Apple-materials convention
  /// both modes follow here. The delta is ~3% luminance — felt, not seen.
  final List<Color> cardGradient;

  static const light = V3Palette(
    // Four tiers, darkest to lightest: canvas → hero → surfaceRaised → surface.
    //
    // Light layering needs fill steps, a hairline, and a real drop shadow at
    // the same time — a hairline alone reads as a wireframe, a shadow alone
    // reads as nothing. The ground is a clean neutral near-white — the macOS
    // #F5F5F7 convention.
    //
    // Pure white appears only in the QR pad of the payment flow, which
    // scanners want white and which hard-codes it instead of reading a token.
    canvas: Color(0xFFF4F4F6),
    surface: Color(0xFFFDFDFD),
    surfaceRaised: Color(0xFFF7F7F9),
    hero: Color(0xFFEBEBED),
    night: Color(0xFF0D1524),
    ink: Color(0xFF0D1524),
    // Secondary text must read crisp, not atmospheric (~8.5:1 on cards).
    inkMuted: Color(0xFF4E4A50),
    line: Color(0xFFDBDBDF),
    hairline: Color(0x2414181C),
    lychee: Color(0xFFF25472),
    lycheeSoft: Color(0xFFFFE3E8),
    citrus: Color(0xFFD7F267),
    aqua: Color(0xFF70D7D5),
    success: Color(0xFF249A6A),
    // Must stay at or above the 3:1 WCAG floor for icons drawn on `canvas`.
    warning: Color(0xFFBA771C),
    danger: Color(0xFFCC3F57),
    // Keep text safe even on a green-tinted hero: #177045 only reached 4.18:1
    // after the 12% success tint was composited onto the darker hero surface.
    lycheeInk: Color(0xFFB32747),
    successInk: Color(0xFF11613A),
    warningInk: Color(0xFF8A5000),
    dangerInk: Color(0xFFB02E45),
    aquaInk: Color(0xFF0B6F6C),
    onLychee: Color(0xFF0D1524),
    // The one deliberate pure white in light mode besides the QR pad: the
    // danger red is dark enough that white clears AA, while night does not
    // (3.6:1). See the QR note under `canvas` above.
    onDanger: Color(0xFFFFFFFF),
    // Soft contact shadow plus a faint ambient lift.
    shadows: [
      BoxShadow(color: Color(0x1A141518), blurRadius: 8, offset: Offset(0, 3)),
      BoxShadow(
        color: Color(0x3D141518),
        blurRadius: 28,
        offset: Offset(0, 12),
        spreadRadius: -8,
      ),
    ],
    cardGradient: [Color(0xFFFDFDFE), Color(0xFFF9F9FA)],
  );

  static const dark = V3Palette(
    // Neutral black staircase. Levels follow the macOS/Fluent dark convention:
    // near-black canvas, two quiet elevation steps, hierarchy from luminance —
    // no hue. The 4-tier staircase: hero < canvas < surface < surfaceRaised.
    canvas: Color(0xFF0A0A0B),
    surface: Color(0xFF161618),
    surfaceRaised: Color(0xFF1F1F22),
    hero: Color(0xFF000000),
    night: Color(0xFF000000),
    ink: Color(0xFFEDEDEF),
    // Neutral gray muted ink, still clearing 4.5:1 on every dark surface
    // (~6:1 on cards).
    inkMuted: Color(0xFF9D9DA3),
    line: Color(0xFF2A2A2E),
    // DLSS5 --hair: white 9%; Fluent's dark card stroke is white ~7%. The same
    // 1px line light draws keeps the "line + light" recipe intact.
    hairline: Color(0x14FFFFFF),
    lychee: Color(0xFFFF6683),
    // Selection fill only: a subdued pink-tinted pocket on black. Surfaces
    // around it stay neutral — the accent lives in small states, not the cast.
    lycheeSoft: Color(0xFF331F24),
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
    onLychee: Color(0xFF0A0A0B),
    onDanger: Color(0xFF0A0A0B),
    // Flat by design: on black, big blurred shadows paint as gray smudges over
    // whatever sits below (the "stacked cards" look). One tight contact shadow
    // for depth over scroll content; separation itself comes from the surface
    // steps and the 1px stroke.
    shadows: [
      BoxShadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 2)),
    ],
    cardGradient: [Color(0xFF1B1B1D), Color(0xFF141416)],
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
      // Complete the M3 roles instead of letting missing slots fall back to
      // the seed defaults (a surprise green/blue on controls that read
      // primaryContainer or tertiary). Containers tint toward the selected
      // pink and the decorative aqua, never toward status green.
      primaryContainer: p.lycheeSoft,
      onPrimaryContainer: p.lycheeInk,
      secondaryContainer: p.lycheeSoft,
      onSecondaryContainer: p.lycheeInk,
      tertiary: p.aqua,
      onTertiary: p.night,
      errorContainer: p.danger.withValues(alpha: .14),
      onErrorContainer: p.dangerInk,
      outlineVariant: p.line,
      inverseSurface: p.ink,
      onInverseSurface: p.surface,
      inversePrimary: p.lycheeInk,
      surfaceContainerHighest: p.surfaceRaised,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.canvas,
      fontFamily: 'Segoe UI',
      fontFamilyFallback: const [
        'Segoe UI Variable',
        'SF Pro Text',
        // Explicit CJK fallback: Windows resolves it anyway, but a named
        // entry keeps CJK metrics identical when the default fallback chain
        // changes (Win11 newer builds, other hosts).
        'Microsoft YaHei UI',
        'Roboto',
        'Noto Sans',
        'sans-serif',
      ],
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
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: p.inkMuted,
        ),
      ),
      dividerColor: p.line,
      // Keep a quiet but visible press state without a spreading ripple.
      // Brand-pink ink: the neutral ink wash read as a grey ghost box on
      // dark surfaces, fighting the lychee selection language it sits in.
      splashFactory: NoSplash.splashFactory,
      highlightColor: p.lychee.withValues(alpha: 0.12),
      // Hover is a quiet ink wash at 4%: desktop feedback that lifts the
      // surface under the pointer without competing with the lychee pressed
      // highlight. Pressables own the full row rect (padding rides inside),
      // so the wash fills the card. Focus draws at 12% — three times the
      // hover strength — so keyboard navigation stays visible: Fluent 2
      // requires a focus rect, M3 raises the same state layer, and a
      // transparent focus on a desktop client hides Tab navigation entirely.
      hoverColor: p.ink.withValues(alpha: 0.04),
      focusColor: p.ink.withValues(alpha: 0.12),
      // Selection follows the cycle chooser: a soft pink ground, dark/light
      // palette-safe lychee ink, and a matching border. Never white on lime.
      chipTheme: ChipThemeData(
        backgroundColor: p.surfaceRaised,
        selectedColor: p.lycheeSoft,
        side: BorderSide(color: p.hairline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(V3Radius.control),
        ),
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
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? p.lycheeSoft
                : p.surfaceRaised,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected) ? p.lycheeInk : p.ink,
          ),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.selected)
                  ? p.lychee
                  : p.hairline,
              width: states.contains(WidgetState.selected) ? 1.5 : 1,
            ),
          ),
          iconColor: WidgetStatePropertyAll(p.lycheeInk),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style:
            FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(V3Radius.field),
              ),
            ).copyWith(
              // The primary action glows in the brand color from underneath —
              // DLSS5's primary casts `0 12px 30px -16px var(--accent)` and
              // Material 3 tints FAB shadows the same way. Disabled drops flat.
              elevation: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.disabled) ? 0.0 : 5.0,
              ),
              shadowColor: WidgetStatePropertyAll(
                p.lychee.withValues(alpha: 0.45),
              ),
              surfaceTintColor: const WidgetStatePropertyAll(
                Colors.transparent,
              ),
            ),
      ),
      // Thin rounded scrollbar, DLSS5/Fluent style: a small pill inset from
      // the track edge rather than a slab glued to it.
      scrollbarTheme: const ScrollbarThemeData(
        thickness: WidgetStatePropertyAll(6),
        crossAxisMargin: 2,
        mainAxisMargin: 3,
        radius: Radius.circular(3),
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
          borderSide: BorderSide(color: p.hairline),
        ),
        // Filled-style inputs: the surfaceRaised fill carries the field, the
        // hairline just edges it; only focus earns the brand pink outline.
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(V3Radius.field),
          borderSide: BorderSide(color: p.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(V3Radius.field),
          borderSide: BorderSide(color: p.lychee, width: 2),
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
