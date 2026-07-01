import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

import '../tool/brand_asset_processor.dart';

void main() {
  test('creates rounded desktop and safe adaptive icon assets', () {
    final source = image.Image(width: 1024, height: 1024, numChannels: 4);
    image.fill(source, color: image.ColorRgba8(25, 110, 220, 255));

    final assets = processBrandLogo(source);

    expect(assets.appIcon.width, 1024);
    expect(assets.appIcon.getPixel(0, 0).a, 0);
    expect(assets.appIcon.getPixel(512, 512).a, 255);
    expect(assets.adaptiveForeground.getPixel(512, 512).a, 0);
    expect(assets.adaptiveBackground.getPixel(0, 0).a, 255);
    expect(assets.trayConnected.width, 64);
    expect(assets.trayDisconnected.height, 64);
  });

  test('preserves a wide logo instead of center-cropping it', () {
    final source = image.Image(width: 1024, height: 512, numChannels: 4);
    image.fill(source, color: image.ColorRgba8(220, 40, 50, 255));

    final assets = processBrandLogo(source);

    expect(assets.appIcon.getPixel(512, 512).a, 255);
    expect(assets.appIcon.getPixel(512, 100).a, 0);
  });

  test('transparent marks use the Android adaptive foreground safe zone', () {
    final source = image.Image(width: 1024, height: 1024, numChannels: 4);
    image.fillRect(
      source,
      x1: 256,
      y1: 256,
      x2: 767,
      y2: 767,
      color: image.ColorRgba8(10, 20, 30, 255),
    );

    final assets = processBrandLogo(source);

    expect(assets.adaptiveForeground.getPixel(0, 0).a, 0);
    expect(assets.adaptiveForeground.getPixel(512, 512).a, 255);
    expect(assets.adaptiveBackground.getPixel(0, 0).a, 255);
  });
}
