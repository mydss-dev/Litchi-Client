import 'dart:math' as math;

import 'package:image/image.dart' as image;

const brandAssetCanvasSize = 1024;

class ProcessedBrandAssets {
  const ProcessedBrandAssets({
    required this.appIcon,
    required this.adaptiveForeground,
    required this.adaptiveBackground,
    required this.trayConnected,
    required this.trayDisconnected,
  });

  final image.Image appIcon;
  final image.Image adaptiveForeground;
  final image.Image adaptiveBackground;
  final image.Image trayConnected;
  final image.Image trayDisconnected;
}

ProcessedBrandAssets processBrandLogo(image.Image source) {
  final rgba = source.convert(numChannels: 4);
  final isNearlySquare =
      (rgba.width / rgba.height).clamp(0.0, double.infinity) >= 0.9 &&
      (rgba.width / rgba.height).clamp(0.0, double.infinity) <= 1.1;
  final canonical = _contain(
    rgba,
    size: brandAssetCanvasSize,
    contentFraction: isNearlySquare ? 1 : 0.9,
  );
  final appIcon = _roundedMask(canonical, radiusFraction: 0.22);
  final hasOpaqueCanvas = isNearlySquare && _isOpaqueCanvas(rgba);
  final adaptiveForeground = hasOpaqueCanvas
      ? image.Image(
          width: brandAssetCanvasSize,
          height: brandAssetCanvasSize,
          numChannels: 4,
        )
      : _contain(
          canonical,
          size: brandAssetCanvasSize,
          // Android launchers may apply circles, squircles, or rounded squares.
          // Keep transparent marks inside the adaptive-icon safe zone.
          contentFraction: 0.66,
        );
  final adaptiveBackground = hasOpaqueCanvas
      ? image.Image.from(canonical)
      : _solidBackground(brandAssetCanvasSize, _backgroundColor(canonical));
  final traySource = _contain(appIcon, size: 256, contentFraction: 0.88);
  final trayConnected = image.copyResize(
    traySource,
    width: 64,
    height: 64,
    interpolation: image.Interpolation.cubic,
  );
  final trayDisconnected = image.grayscale(image.Image.from(trayConnected));

  return ProcessedBrandAssets(
    appIcon: appIcon,
    adaptiveForeground: adaptiveForeground,
    adaptiveBackground: adaptiveBackground,
    trayConnected: trayConnected,
    trayDisconnected: trayDisconnected,
  );
}

image.Image _contain(
  image.Image source, {
  required int size,
  required double contentFraction,
}) {
  final maxContent = math.max(1, (size * contentFraction).round());
  final scale = math.min(maxContent / source.width, maxContent / source.height);
  final width = math.max(1, (source.width * scale).round());
  final height = math.max(1, (source.height * scale).round());
  final resized = image.copyResize(
    source,
    width: width,
    height: height,
    interpolation: image.Interpolation.cubic,
  );
  final canvas = image.Image(width: size, height: size, numChannels: 4);
  return image.compositeImage(
    canvas,
    resized,
    dstX: (size - width) ~/ 2,
    dstY: (size - height) ~/ 2,
  );
}

bool _isOpaqueCanvas(image.Image source) {
  var opaque = 0;
  var sampled = 0;
  final stepX = math.max(1, source.width ~/ 32);
  final stepY = math.max(1, source.height ~/ 32);
  for (var y = 0; y < source.height; y += stepY) {
    for (var x = 0; x < source.width; x += stepX) {
      sampled++;
      if (source.getPixel(x, y).a >= 245) opaque++;
    }
  }
  return sampled > 0 && opaque / sampled >= 0.9;
}

image.Image _roundedMask(image.Image source, {required double radiusFraction}) {
  final result = source.convert(numChannels: 4);
  final radius = math.min(result.width, result.height) * radiusFraction;
  final right = result.width - 1.0;
  final bottom = result.height - 1.0;
  for (final pixel in result) {
    final x = pixel.x.toDouble();
    final y = pixel.y.toDouble();
    final nearestX = x < radius
        ? radius
        : (x > right - radius ? right - radius : x);
    final nearestY = y < radius
        ? radius
        : (y > bottom - radius ? bottom - radius : y);
    final distance = math.sqrt(
      math.pow(x - nearestX, 2) + math.pow(y - nearestY, 2),
    );
    final coverage = (radius + 0.5 - distance).clamp(0.0, 1.0);
    pixel.a = (pixel.a * coverage).round();
  }
  return result;
}

image.Color _backgroundColor(image.Image source) {
  final samples = <image.Pixel>[
    source.getPixel(0, 0),
    source.getPixel(source.width - 1, 0),
    source.getPixel(0, source.height - 1),
    source.getPixel(source.width - 1, source.height - 1),
  ].where((pixel) => pixel.a > 128).toList();

  if (samples.isNotEmpty) {
    final red =
        samples.fold<num>(0, (sum, pixel) => sum + pixel.r) ~/ samples.length;
    final green =
        samples.fold<num>(0, (sum, pixel) => sum + pixel.g) ~/ samples.length;
    final blue =
        samples.fold<num>(0, (sum, pixel) => sum + pixel.b) ~/ samples.length;
    return image.ColorRgba8(red, green, blue, 255);
  }

  var red = 0.0;
  var green = 0.0;
  var blue = 0.0;
  var count = 0;
  for (var y = 0; y < source.height; y += 16) {
    for (var x = 0; x < source.width; x += 16) {
      final pixel = source.getPixel(x, y);
      if (pixel.a <= 32) continue;
      red += pixel.r;
      green += pixel.g;
      blue += pixel.b;
      count++;
    }
  }
  if (count == 0) return image.ColorRgba8(245, 247, 250, 255);
  final luminance =
      (0.2126 * red + 0.7152 * green + 0.0722 * blue) / count / 255;
  return luminance > 0.72
      ? image.ColorRgba8(31, 41, 55, 255)
      : image.ColorRgba8(245, 247, 250, 255);
}

image.Image _solidBackground(int size, image.Color color) {
  final background = image.Image(width: size, height: size, numChannels: 4);
  return image.fill(background, color: color);
}
