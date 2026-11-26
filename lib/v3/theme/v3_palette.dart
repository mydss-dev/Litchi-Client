import 'package:material_ui/material_ui.dart';

/// Litchi's visual language: Elegant — quiet neutral canvas, coral status
/// accent, green for connected/confirmed, aqua as the fourth note.
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
    required this.citrusInk,
    required this.onLychee,
    required this.onDanger,
    required this.shadows,
    required this.glass,
    required this.glassBorder,
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
  /// wireframe, a shadow alone reads as nothing.
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
  /// The four colors above are tuned as fills and icons: on a light ground
  /// they clear the WCAG asks for graphics; small colored labels and error
  /// messages use these darker inks, which clear AA against every light
  /// surface. Dark mode inks are the base colors themselves.
  final Color lycheeInk;
  final Color successInk;
  final Color warningInk;
  final Color dangerInk;

  /// The one ink for [aqua], which the gauge strip needed to complete its
  /// four-accent spread. Light mode darkens the decorative aqua; dark mode is
  /// the base aqua itself.
  final Color aquaInk;

  /// The one ink for [citrus] as a *foreground*.
  final Color citrusInk;

  /// Foregrounds drawn on top of solid [lychee] fills (primary buttons, the
  /// connect orb). Dark ink clears AA on the coral fill in both modes.
  final Color onLychee;

  /// Foreground on solid [danger] fills.
  final Color onDanger;

  /// Soft diffuse shadows for floating surfaces (panels, the rail, dialogs).
  ///
  /// Light mode layers three diffuse passes (contact + mid + far) so cards
  /// read as floating; dark mode keeps one deep pass (big blurs on black
  /// paint as gray smudges otherwise).
  final List<BoxShadow> shadows;

  /// Two-step vertical wash a workspace card fills itself with: a touch
  /// brighter at the top, a touch sunk at the bottom, straddling [surface].
  final List<Color> cardGradient;

  /// Light glassmorphism fill (rail + control panel only; mobile stays
  /// opaque). Dark variant is a deep neutral at 80%.
  final Color glass;

  /// The 1px highlight stroke that rides on top of [glass].
  final Color glassBorder;

  static V3Palette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  static const light = V3Palette(
    // Four tiers, darkest to lightest: canvas -> hero -> surfaceRaised -> surface.
    canvas: Color(0xFFF1F2F4),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFF6F7F9),
    hero: Color(0xFFEAECF0),
    night: Color(0xFF17191E),
    ink: Color(0xFF17191E),
    // Secondary text reads crisp, not atmospheric (~6:1 on cards).
    inkMuted: Color(0xFF5D6470),
    line: Color(0xFFE4E6EB),
    hairline: Color(0x1217191E),
    cardGradient: [Color(0xFFFFFFFF), Color(0xFFFAFAFB)],
    lychee: Color(0xFFF25E48),
    lycheeSoft: Color(0xFFFFE8E2),
    citrus: Color(0xFFF2C14E),
    aqua: Color(0xFF58C7C4),
    success: Color(0xFF16A75F),
    // Must stay at or above the 3:1 WCAG floor for icons drawn on canvas.
    warning: Color(0xFFBA771C),
    danger: Color(0xFFD5321F),
    lycheeInk: Color(0xFFB03A26),
    successInk: Color(0xFF096B38),
    warningInk: Color(0xFF8A5000),
    dangerInk: Color(0xFFA8281B),
    aquaInk: Color(0xFF0B6F6C),
    citrusInk: Color(0xFF8A5B00),
    onLychee: Color(0xFF17191E),
    onDanger: Color(0xFFFFFFFF),
    shadows: [
      BoxShadow(color: Color(0x0D17191F), offset: Offset(0, 1), blurRadius: 2),
      BoxShadow(color: Color(0x1A17191F), offset: Offset(0, 6), blurRadius: 16, spreadRadius: -6),
      BoxShadow(color: Color(0x1A17191F), offset: Offset(0, 16), blurRadius: 40, spreadRadius: -16),
    ],
    glass: Color(0xB8FFFFFF),
    glassBorder: Color(0x80FFFFFF),
  );

  static const dark = V3Palette(
    // Neutral black staircase: hero < canvas < surface < surfaceRaised.
    canvas: Color(0xFF101217),
    surface: Color(0xFF191C22),
    surfaceRaised: Color(0xFF242830),
    hero: Color(0xFF0F1116),
    night: Color(0xFF000000),
    ink: Color(0xFFF0F1F3),
    inkMuted: Color(0xFFA6ACB6),
    line: Color(0xFF30343C),
    hairline: Color(0x14FFFFFF),
    cardGradient: [Color(0xFF1B1D20), Color(0xFF121417)],
    lychee: Color(0xFFFF8A72),
    lycheeSoft: Color(0xFF33231F),
    citrus: Color(0xFFF2C14E),
    aqua: Color(0xFF79E0DC),
    success: Color(0xFF3FD68C),
    warning: Color(0xFFF1BD59),
    danger: Color(0xFFE5484D),
    lycheeInk: Color(0xFFFF8A72),
    successInk: Color(0xFF3FD68C),
    warningInk: Color(0xFFF1BD59),
    dangerInk: Color(0xFFFF8A8C),
    aquaInk: Color(0xFF79E0DC),
    citrusInk: Color(0xFFF2C14E),
    onLychee: Color(0xFF0B0C0E),
    onDanger: Color(0xFF0B0C0E),
    shadows: [
      BoxShadow(color: Color(0x73000000), offset: Offset(0, 8), blurRadius: 32),
    ],
    glass: Color(0xCC191C22),
    glassBorder: Color(0x1FFFFFFF),
  );
}

/// Corner radius tiers. Every box draws one of these four curves instead of
/// inventing its own — the sweep keeps the app soft and floating:
///
/// * [control] — chips, tags, tooltips, mini icon tiles.
/// * [field] — text inputs, every button, segmented tracks, small tiles.
/// * [card] — list rows, standard cards, inner panels. This is the curve a
///   workspace card draws unless told otherwise.
/// * [panel] — page-level panels, dialogs, sheets, the glass rail.
/// * [glyph] — micro glyph shapes below the control tier: latency signal
///   bars, flag chips, chart column tops.
///
/// Two non-tier values remain literal on purpose: the 2dp progress hairline
/// and the 99 pill.
abstract final class V3Radius {
  static const double control = 12;
  static const double field = 16;
  static const double card = 22;
  static const double panel = 28;
  static const double glyph = 3;
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
      // Material controls that fall back to secondary must still select coral.
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
      // coral and the decorative aqua, never toward status green.
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
      // Brand-coral ink: the neutral ink wash read as a grey ghost box on
      // dark surfaces, fighting the coral selection language it sits in.
      splashFactory: NoSplash.splashFactory,
      highlightColor: p.lychee.withValues(alpha: 0.12),
      // Hover is a quiet ink wash at 4%: desktop feedback that lifts the
      // surface under the pointer without competing with the coral pressed
      // highlight. Focus draws at 12% — three times the hover strength — so
      // keyboard navigation stays visible.
      hoverColor: p.ink.withValues(alpha: 0.04),
      focusColor: p.ink.withValues(alpha: 0.12),
      // Selection follows the cycle chooser: a soft coral ground,
      // palette-safe coral ink, and a matching border. Never white on lime.
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
      // One global fallback prevents new segmented controls regressing to
      // green.
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          // One selection language app-wide: a raised neutral track with a
          // surface thumb and ink label (same as V3MobileSegmented). Coral
          // never means "selected".
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? p.surface
                : p.surfaceRaised,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected) ? p.ink : p.inkMuted,
          ),
          side: WidgetStatePropertyAll(BorderSide(color: p.hairline)),
          iconColor: WidgetStatePropertyAll(p.ink),
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
              // Flat primary actions: a coloured glow under every button read
              // as a stuck focus ring and competed with the content.
              elevation: const WidgetStatePropertyAll(0.0),
              shadowColor: const WidgetStatePropertyAll(Colors.transparent),
              surfaceTintColor: const WidgetStatePropertyAll(
                Colors.transparent,
              ),
            ),
      ),
      // Thin rounded scrollbar, a small pill inset from the track edge
      // rather than a slab glued to it.
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
        // hairline just edges it; only focus earns the coral outline.
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
