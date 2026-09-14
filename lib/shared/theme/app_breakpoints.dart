/// Shared responsive thresholds. Pages should classify a layout rather than
/// embedding one-off width literals in their build methods.
class AppBreakpoints {
  AppBreakpoints._();

  static const double compact = 600;
  static const double medium = 900;

  static bool isCompact(double width) => width < compact;
  static bool isMedium(double width) => width >= compact && width < medium;
  static bool isExpanded(double width) => width >= medium;
}
