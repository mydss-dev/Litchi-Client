import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as image;

const _maxDownloadBytes = 10 * 1024 * 1024;
const _canvasSize = 1024;
const _icoSizes = [256, 128, 64, 48, 40, 32, 24, 20, 16];

Future<void> main(List<String> args) async {
  final bytes = args.isNotEmpty
      ? await File(args.first).readAsBytes()
      : await _downloadLogoFromEnvironment();
  final decoded = image.decodeImage(bytes);
  if (decoded == null) {
    throw StateError('logo_url is not a supported image');
  }
  if (decoded.width != decoded.height) {
    throw StateError(
      'Logo must be square; received ${decoded.width}x${decoded.height}. '
      'Upload a 1024x1024 PNG.',
    );
  }
  if (decoded.width < 512) {
    throw StateError(
      'Logo is too small (${decoded.width}x${decoded.height}); minimum is '
      '512x512, recommended is 1024x1024 PNG.',
    );
  }

  final canonical = image.copyResize(
    decoded.convert(numChannels: 4),
    width: _canvasSize,
    height: _canvasSize,
    interpolation: image.Interpolation.cubic,
  );
  final outputDir = Platform.environment['BRAND_ASSET_DIR']?.trim();
  await _saveAssets(
    canonical,
    Directory(
      outputDir == null || outputDir.isEmpty ? 'assets/images' : outputDir,
    ),
  );
  stdout.writeln(
    'Brand assets generated: in-app PNG, launcher source, connected tray ICO, '
    'disconnected grayscale tray ICO.',
  );
}

Future<Uint8List> _downloadLogoFromEnvironment() async {
  final logoUrl = (Platform.environment['LOGO_URL'] ?? '').trim();
  final uri = Uri.tryParse(logoUrl);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
    throw StateError('logo_url is required and must use https');
  }
  return _download(uri);
}

Future<Uint8List> _download(Uri uri) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final request = await client
        .getUrl(uri)
        .timeout(const Duration(seconds: 20));
    request.headers
      ..set(HttpHeaders.userAgentHeader, 'LitchiBuild/1.0')
      ..set(HttpHeaders.acceptHeader, 'image/png,image/*');
    final response = await request.close().timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('Logo download failed: HTTP ${response.statusCode}');
    }
    if (response.contentLength > _maxDownloadBytes) {
      throw StateError('Logo is larger than 10 MB');
    }

    final builder = BytesBuilder(copy: false);
    var length = 0;
    await for (final chunk in response.timeout(const Duration(seconds: 20))) {
      length += chunk.length;
      if (length > _maxDownloadBytes) {
        throw StateError('Logo is larger than 10 MB');
      }
      builder.add(chunk);
    }
    return builder.takeBytes();
  } finally {
    client.close(force: true);
  }
}

Future<void> _saveAssets(image.Image logo, Directory assets) async {
  await assets.create(recursive: true);

  await File('${assets.path}/logo.png').writeAsBytes(image.encodePng(logo));
  await File('${assets.path}/app_icon.png').writeAsBytes(image.encodePng(logo));

  await File(
    '${assets.path}/app_icon_foreground.png',
  ).writeAsBytes(image.encodePng(logo));

  await File(
    '${assets.path}/tray_icon.ico',
  ).writeAsBytes(_encodeVerifiedIco(logo));

  final gray = image.grayscale(image.Image.from(logo));
  await File(
    '${assets.path}/tray_icon_gray.ico',
  ).writeAsBytes(_encodeVerifiedIco(gray));

  await File('${assets.path}/tray_icon.png').writeAsBytes(
    image.encodePng(
      image.copyResize(
        logo,
        width: 64,
        height: 64,
        interpolation: image.Interpolation.cubic,
      ),
    ),
  );
  await File('${assets.path}/tray_icon_gray.png').writeAsBytes(
    image.encodePng(
      image.copyResize(
        gray,
        width: 64,
        height: 64,
        interpolation: image.Interpolation.cubic,
      ),
    ),
  );
}

image.Image _multiSizeIcon(image.Image source) {
  final icon = image.copyResize(
    source,
    width: _icoSizes.first,
    height: _icoSizes.first,
    interpolation: image.Interpolation.cubic,
  );
  for (final size in _icoSizes.skip(1)) {
    icon.addFrame(
      image.copyResize(
        source,
        width: size,
        height: size,
        interpolation: image.Interpolation.cubic,
      ),
    );
  }
  return icon;
}

Uint8List _encodeVerifiedIco(image.Image source) {
  final bytes = image.encodeIco(_multiSizeIcon(source));
  final decoded = image.decodeIco(bytes);
  if (decoded == null || decoded.width < 16 || decoded.height < 16) {
    throw StateError('Generated tray ICO failed validation');
  }
  return bytes;
}
