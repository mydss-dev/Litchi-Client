import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.first == '--help' || args.first == 'help') {
    _usage();
    return;
  }

  final source = args.first;
  final generateIcons = !args.contains('--no-generate-icons');
  final metadataOnly = args.contains('--metadata-only');
  final payload = source.startsWith('--app-name=')
      ? <String, dynamic>{
          'app_name': source.substring('--app-name='.length),
          'logo_url': _argumentValue(args, '--logo-url='),
        }
      : await _loadPayload(source);
  if (payload == null) {
    exitCode = 65;
    return;
  }

  final appName = _string(payload['app_name'], fallback: 'Litchi Client');
  final windowsExeName = '${sanitizeWindowsExecutableBaseName(appName)}.exe';
  final logo = _string(payload['logo_url']);

  stdout.writeln('Branding source: $source');
  stdout.writeln('App name: $appName');
  stdout.writeln('Logo: ${logo.isEmpty ? '(empty)' : logo}');

  await _writeAndroidName(appName);
  await _writeWindowsName(appName, windowsExeName);
  await _writeMacOsName(appName);

  if (!metadataOnly) {
    final downloadedIcon = await _downloadLogoIfUrl(logo);
    if (downloadedIcon) {
      await _patchLauncherIconPaths();
      if (generateIcons) await _generateLauncherIcons();
    } else {
      stdout.writeln(
        'Logo is not an http(s) image URL, keep existing launcher icons.',
      );
    }
  }

  stdout.writeln('Branding applied.');
}

void _usage() {
  stdout.writeln('''
Usage:
  dart run tool/apply_branding.dart <config.js|payload.json|oss_config.json|https_url> [--no-generate-icons] [--metadata-only]
  dart run tool/apply_branding.dart --app-name="My Client" [--logo-url=https://example.com/logo.png] [--metadata-only]

The tool reads existing remote config fields:
  app_name     -> Android label + Windows product metadata
  logo_url  -> if http(s), download launcher-icon assets; runtime logo stays cloud-only

Examples:
  dart run tool/apply_branding.dart config.js
  dart run tool/apply_branding.dart oss_config.json
  dart run tool/apply_branding.dart https://example.com/config.json
''');
}

String _argumentValue(List<String> args, String prefix) {
  for (final argument in args) {
    if (argument.startsWith(prefix)) return argument.substring(prefix.length);
  }
  return '';
}

Future<Map<String, dynamic>?> _loadPayload(String source) async {
  try {
    String raw;
    if (source.startsWith('http://') || source.startsWith('https://')) {
      raw = await _httpGetText(source);
    } else if (source.toLowerCase().endsWith('.js')) {
      final result = await Process.run('node', [source]);
      if (result.exitCode != 0) {
        stderr.writeln(result.stderr);
        return null;
      }
      raw = '${result.stdout}';
    } else {
      raw = await File(source).readAsString();
    }

    final decoded = jsonDecode(raw.trim());
    if (decoded is! Map) {
      stderr.writeln('Config must be a JSON object.');
      return null;
    }
    final json = Map<String, dynamic>.from(decoded);

    final payloadB64 = json['payload_b64'];
    if (payloadB64 is String && payloadB64.isNotEmpty) {
      final payloadRaw = utf8.decode(_b64decode(payloadB64));
      final payloadDecoded = jsonDecode(payloadRaw);
      if (payloadDecoded is Map) {
        return Map<String, dynamic>.from(payloadDecoded);
      }
      stderr.writeln('payload_b64 must decode to a JSON object.');
      return null;
    }

    return json;
  } catch (e) {
    stderr.writeln('Failed to load branding config: $e');
    return null;
  }
}

Future<void> _writeAndroidName(String appName) async {
  final dir = Directory('android/app/src/main/res/values');
  await dir.create(recursive: true);
  final file = File('${dir.path}/strings.xml');
  final escaped = _xmlEscape(appName);
  await file.writeAsString('''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">$escaped</string>
</resources>
''');

  final manifest = File('android/app/src/main/AndroidManifest.xml');
  if (await manifest.exists()) {
    var text = await manifest.readAsString();
    text = text.replaceAllMapped(
      RegExp(r'android:label="[^"]*"'),
      (_) => 'android:label="@string/app_name"',
    );
    await manifest.writeAsString(text);
  }
  stdout.writeln('Android app label updated.');
}

Future<void> _writeWindowsName(String appName, String executableName) async {
  final file = File('windows/runner/Runner.rc');
  if (!await file.exists()) return;
  var text = await file.readAsString();
  final escaped = _rcEscape(appName);
  final company = _rcEscape(_companyName(appName));

  text = _replaceRcValue(text, 'CompanyName', company);
  text = _replaceRcValue(text, 'FileDescription', escaped);
  text = _replaceRcValue(text, 'InternalName', escaped);
  text = _replaceRcValue(text, 'ProductName', escaped);
  text = _replaceRcValue(text, 'OriginalFilename', executableName);
  text = _replaceRcValue(
    text,
    'LegalCopyright',
    'Copyright (C) 2026 $company. All rights reserved.',
  );

  await file.writeAsString(text);
  stdout.writeln('Windows product metadata updated.');
}

String sanitizeWindowsExecutableBaseName(String appName) {
  var cleaned = appName
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .replaceAll(RegExp(r'[. ]+$'), '');
  final runes = cleaned.runes.take(60).toList(growable: false);
  cleaned = String.fromCharCodes(runes).replaceAll(RegExp(r'[. ]+$'), '');
  if (RegExp(
    r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])$',
    caseSensitive: false,
  ).hasMatch(cleaned)) {
    cleaned = '$cleaned-App';
  }
  return cleaned.isEmpty ? 'Client-App' : cleaned;
}

Future<void> _writeMacOsName(String appName) async {
  final file = File('macos/Runner/Configs/AppInfo.xcconfig');
  if (!await file.exists()) return;
  var text = await file.readAsString();
  final safeName = appName.replaceAll(RegExp(r'[\r\n]'), ' ').trim();
  final pattern = RegExp(r'^APP_DISPLAY_NAME\s*=.*$', multiLine: true);
  if (pattern.hasMatch(text)) {
    text = text.replaceFirst(pattern, 'APP_DISPLAY_NAME = $safeName');
  } else {
    text = '${text.trimRight()}\nAPP_DISPLAY_NAME = $safeName\n';
  }
  await file.writeAsString(text);
  stdout.writeln('macOS display name updated.');
}

Future<bool> _downloadLogoIfUrl(String logo) async {
  final uri = Uri.tryParse(logo);
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return false;
  }

  try {
    final bytes = await _httpGetBytes(uri);
    if (bytes.isEmpty) return false;
    final dir = Directory('assets/images');
    await dir.create(recursive: true);
    final source = File('${dir.path}/app_icon.png');
    await source.writeAsBytes(bytes);
    final result = await Process.run(Platform.resolvedExecutable, [
      'run',
      'tool/prepare_brand_assets.dart',
      source.path,
    ]);
    if (result.exitCode != 0) {
      throw StateError('Brand asset generation failed: ${result.stderr}');
    }
    stdout.writeln('Generated launcher and tray icons from the cloud logo.');
    return true;
  } catch (e) {
    stderr.writeln('Failed to download logo image: $e');
    return false;
  }
}

Future<void> _patchLauncherIconPaths() async {
  final file = File('pubspec.yaml');
  if (!await file.exists()) return;
  var text = await file.readAsString();
  text = text.replaceAll(
    RegExp(r'image_path:\s*"assets/images/[^"]+"'),
    'image_path: "assets/images/app_icon.png"',
  );
  text = text.replaceAll(
    RegExp(r'adaptive_icon_foreground:\s*"assets/images/[^"]+"'),
    'adaptive_icon_foreground: "assets/images/app_icon_foreground.png"',
  );
  text = text.replaceAll(
    RegExp(r'adaptive_icon_background:\s*(?:"[^"]+"|#[A-Fa-f0-9]+)'),
    'adaptive_icon_background: "assets/images/app_icon_background.png"',
  );
  await file.writeAsString(text);
  stdout.writeln('Launcher icon paths updated in pubspec.yaml.');
}

Future<void> _generateLauncherIcons() async {
  stdout.writeln('Generating launcher icons...');
  final result = await Process.run('dart', [
    'run',
    'flutter_launcher_icons',
  ], runInShell: Platform.isWindows);

  if (result.stdout.toString().trim().isNotEmpty) stdout.writeln(result.stdout);
  if (result.stderr.toString().trim().isNotEmpty) stderr.writeln(result.stderr);

  if (result.exitCode != 0) {
    stderr.writeln(
      'flutter_launcher_icons failed. Run `flutter pub get` first, or rerun with --no-generate-icons.',
    );
    exitCode = result.exitCode;
  }
}

String _replaceRcValue(String text, String key, String value) {
  final escaped = _rcEscape(value);
  return text.replaceAllMapped(
    RegExp('VALUE "${RegExp.escape(key)}", "[^"]*" "\\\\0"'),
    (_) => 'VALUE "$key", "$escaped" "\\0"',
  );
}

String _string(Object? value, {String fallback = ''}) {
  if (value is! String) return fallback;
  final trimmed = value.trim();
  return trimmed.isEmpty ? fallback : trimmed;
}

String _companyName(String appName) {
  final clean = appName.trim();
  if (clean.isEmpty) return 'Litchi';
  return clean.split(RegExp(r'\s+')).first;
}

String _xmlEscape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

String _rcEscape(String value) =>
    value.replaceAll('\\', '\\\\').replaceAll('"', '\\"');

Future<String> _httpGetText(String url) async {
  final bytes = await _httpGetBytes(Uri.parse(url));
  return utf8.decode(bytes);
}

Future<List<int>> _httpGetBytes(Uri uri) async {
  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 15);
  try {
    final request = await client.getUrl(uri);
    request.headers.set(HttpHeaders.userAgentHeader, 'WhiteLabelBuild/1.0');
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('HTTP ${response.statusCode}', uri: uri);
    }
    return response.fold<List<int>>(
      <int>[],
      (prev, chunk) => prev..addAll(chunk),
    );
  } finally {
    client.close(force: true);
  }
}

List<int> _b64decode(String raw) {
  final normalized = raw.trim().replaceAll('-', '+').replaceAll('_', '/');
  final padded = normalized.padRight(
    normalized.length + ((4 - normalized.length % 4) % 4),
    '=',
  );
  return base64.decode(padded);
}
