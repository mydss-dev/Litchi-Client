class AppLaunchOptions {
  const AppLaunchOptions({required this.silent});

  final bool silent;

  factory AppLaunchOptions.parse(List<String> arguments) {
    final normalized = arguments.map((value) => value.trim().toLowerCase());
    return AppLaunchOptions(
      silent:
          normalized.contains('--silent') ||
          normalized.contains('--start-minimized'),
    );
  }
}
