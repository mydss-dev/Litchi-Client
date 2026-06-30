import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as image;

const _maxDownloadBytes = 10 * 1024 * 1024;
const _canvasSize = 1024;
const _icoSizes = [256, 128, 64, 48, 40, 32, 24, 20, 16];

// Built-in fallback icon used only when the tenant logo URL is missing or broken.
// It keeps CI/white-label builds from failing because of a deleted OSS/R2 image.
const _fallbackLogoPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAgAAAAIACAYAAAD0eNT6AAAT70lEQVR42u3d249dVR0H8H2a8+RtCgwJlwLe/4ImLZRL6dB44Zb4jJTEckflwQugjYmIAqIvahXFSoF3BS20QCsiYJv0L0BLBMq9KgPG1+NDaaDTmc4+5+zLWuv3+STnCWbS2bPP+n7Xb++zZzC64u5RBQCEMhyN5D8ARLPCIQAABQAAUAAAAAUAAFAAAAAFAABQAAAABQAAUAAAgP4MK08CBAATAAAgwATA/h8ATAAAAAUAAFAAAAAFAABQAAAABQAAUAAAgGQMq8qTAAAgXgGQ/wAQjksAAKAAAAAKAABQJH8MCABMAAAABQAAUAAAAAUAAMiUJwECgAkAABBjAmAAAAAmAACAAgAAKAAAgAIAACgAAEAe/DEgADABAABCTAA8CRAATAAAAAUAACiRRwEDgAkAAKAAAAAKAACgAAAACgAAoAAAAAoAAJCO4ciDAADABAAAUAAAgAJ5FDAAmAAAAAoAAKAAAAAKAACgAAAACgAAkKxh5XOAAGACAAAEmADY/wOACQAAEGEC4BYAADABAAAUAABAAQAAFAAAQAEAADLhSYAAYAIAACgAAIACAAAoAABApoYj9wACgAkAAKAAAAAKAACgAAAAWfIkQAAwAQAAFAAAQAEAAMowdAiAKDZc8fzU32PPQ591ICmkALgHECgt6L/8fHvfe4kSsedBxQATAIBiAn/Sf4NCgAIAUGjo1/33KQMkWQBcAQByMZd46NcpA7uVAUwAAMoN/To/jzJAzwXADABIMSj/Hqbc7H7wM37hmAAAgj/qz6wIoAAAgj/wMVAE6IInAQLC3/HABABA0JkGYAIAIPwdJwqdAPgQANBloF0p0CaeBjxgGoAJACD8HT9QAADh5TiCAgAILccTFABAWOXgrb0HHVc6M/jfl77nNkCgFRdd+Q8HYYLgP3ntqtpf++QDn3YAMQEAhH/Ju37HGQUAEP4FBP9S4T9uKXC8UQAA4V/Irl8JQAEAhH+AXb/jjwIAEHTX38TXQF0eBQw0s/vcZPfZZIiP80mAhVOAJ7f7ZAAmAIDwDxP+fh+MNwEAEDZFBP/C34tJACYAAIHCH2pOANwEAEy6yzzgICQc/IenAJ/yy8EEAMCuH96bANj/A5PYaPefRfBftOlA9YQpACYAAHb9UFU+BQAg+DEBAKgj6vg/1/B3uQYTAAC7fnivALgLEBhnN3lVrN1kKeG/cdOB6on73QyICQCAXT+huQcAQPgTcwLgGgBAjOC33mMCAGDXT/QJAEA9G696QfBnHPwbr3qheuL+TzqRUQCgRB/6/fcPtfbNH75iVvjb9aMAAKUFfBCCH/wxIEjWhwW98G+BNR8TABD2gt+uHwUAEPjCX/gTqwCYB0E3of8HoS/4E2DNxwQABL7wt+sndAFQB6G50L9d6At+IwBMAEDwI/xBAQChj+CHRAz+e/l3zYNA8Ne2LrGnAQr/+h7/3Se8gTEBAKFv1w8KACD4hT8oACD4Bb/gBwUABD/CHwozeNdNgFB9RPCPpcsbAQV/M3a5AZBjJgDin8jB/7Dgt+sPwlrPMROAy0wAEPykNQUQ/A3v/rfZ/bPYBEAtJFz4/0D42/Xb/qMAOAQIfgQ/xDN497LvqIYIfibS1GUA4d+eXds+7iBgAoDwx64fMAFA8JPAFGDcEiD87f4xAQDhH4jgBxMAEPzBpgDC3+6f5q1wCBD+TOvZyx+a6vgvFfAnr10l/IU/CgAI/5JLgF2/8KdbHgVMvsH/iOAvyclrV1Vv7T0o+KdlTaemwTuX3uZ0ITsffeQO4Z+oLv9QEEfb+duzHARqcwkA4U+jmr4UgPDHBADBL1hMAhD+mAAg/DEJQPijACD8UQKEPygACH+UAOEPCgDCHyVA+IMCgPBHCRD+KAAg/FEChD/B+Bggwp9e+Jig4KfvAnDJrQoAaYT/H38o/Bs0v+GGxgJ2Zs/WVn43SkCN8L/vTAcBBQDBTzsB33dBUAQEPwoACgCJh31bpUAJEP50XADmFQB69DHhX0zgN1UIIheBxwQ/CgDCX+iXrE4ZiFQEBD8KAMJf6IezXBkouQh88GOR71x6m0sgKAAIf6GvDJRaBo73LAQlAAUA4S/4FYFl5FQGxnkAkhKAAoDwF/pkXAameeqhEoACgPAX/IxRBPosBE0/5lgJoP0CcPEtCgDthv+ffhQm/AV/WkWgjWLQ5d8zeOeSW51PKAAIf8FPU0UgJ0oAbRk6BCD4cz72UYoAmABg9y/4CTYRMAWgDSscAoS/8Pd78X4i4ATgbRMAmt6JFbpYCX7TgN7PQZMAGuQeABD8xf7O3B8AS3MJALt/4a+8eX+hAIDFSfgrAd5nROAeACxKBQTGzNzqfUv+PLv3r3GGvnecCrok4H4ApjWsKvkPuYb/8YJ/4f+jCBz+/ZZTAqzdTDsB+OK3nUVMF0I77ixiQc0p/OsEv4lA+ZOA+YtvMQVAAUD42/UrARGLgBLApNwESGgRw7/J7+P3DwoAdv8W/0zCXwkoqwSUcgkOBQCLjkUf54MSgAIAFvs2d+umAEohCgCE2G1Y5Cn1/DAFYOwCMKoOf5rUy6vuy+Jexu7fFKC8EmB98hrn5Y8BMZaVme4y5jfcMOtpeYx1vmT4EcGVO+489LaPBVJ3AuAQUHr4V3dsO7DcLndmbvU+O2FKmASsdCmAmjwKmHLdse3AuF/isbmUMAmwrlNvAuBCiFeN18odd+W1CE4Q/osVAchxErByx12HrFtey71cAsDOXwmgwBIAy08AYLndxKMZ7f4bCn8lgNxLQFbvWxQAYJHgafl+BPc7mASgAIDdvykABZUAUwAUACzKpgB2/843UAAob/fgaXlgCsB4PAmQInZjM3OrDxT/c+7ev6bJIpLL7j/VJzjm+4wAMAGggF1DtFFsU4GXQ/jXeTpj309wzOX8MwVg0QnAyBOjyHjnH/LnnnISkHr4T/Kz9fkEx1wmAdZ6TABY1gmP3m23kEEJGDfsJvmaHMK/ya/3vibUBEApxO4/7yKwXPCVcK1/3O/T9c+czf0A1nuOKgAg/IspArlqeueuBMDyXALgKCc8lvaYcKnw97Q8lNP839+YAEBYM1s2b68VNLfft6mYn7ml6/Z9TAEgJ4N/f/6brgqR9e6/7TBpO0Tqhn6pZaDNG/f6KgCpXwr4zxe+5TIaJgCQ+m6/7vfJsQh08QRHUwBYnHsAyELda6tNL/ZthMfMls3bmwr/Lr4v7Z2voADQu5TH/+Mupik/La+LgFYClICc3+90Z+iDoRS5+Cb2tLyuQznnywJ0xdpvAoDd/2M/Lmb3vzDEU3haXp87ctMAU4Ac3/coANDYNGC5UG/rMbkpBLASACxmODIFIsjuqeu7wVMK3pktm7e7HNDfeZzqxwKt/yYABHbiTmNAegxHT3D0/kcBgDZ3/33suP2bKOV8RgEAMg/aFP9tbe3S7f5BAcBuCZzXoABwhOt/sXb/kaYAdv/WARQA7JLI5Xef8BMcnd8UWgBGlVfUF9F2/6n/W6cNbzv/SVkPI75MAII6cec9xn4kOwlI4QmO1gMCTAAgkYXfeJQxQz3H4Heek4qhQwDTy/Ez9rk8HdDOHtoqAC4FY1cEnZ/vyT0eWBbEKwB+5/GctMv1PuBoJ+6659C/PvcNRTwQ9wAAgAIA3TP+x3kPCgAAoAAAAAoAU0vtBkBjUCJL7fx3g3AsQ5/9AOB9MsEEAABQAKBpJY3/c3iiXgn/Zu8DUAAAgCl4FDAA75MJJgCU56THf+IO3xblNFI3/sc6gQJAPwHkuid4P9BvARhVhyc+XuW/sLO2+6cO62WMlwkAAEScADgEEGeHbfcPfKAAGIS4CECEoBX+1Ge9jPAyAaD7IHLDE3hfkMIEACh9x233DygAQc0+/lOf7Q0avMIf6wUKAAQLYOEPLMWjgKHDIJ7Zsnm74CcLssEEAMgrmIU/UG8CABQxDRD8gAIAgYqA4AcUANIPPZ91Pm6A1y0DQr/c98fMnq3uwKebAjBypwckWQagT7KhfG4CBAAFAABQAAAABQAAKIMnAQJwLNlgAgAAlDgBAFo1M7d631L/bX73/jWOEKAAQJDgX/j/KAKAAgABgl8RABIoAO70gD7Df+HXKwGkQTaUzk2AkEj4N/19ABQAyCT8lQCgK0NDHgAWkg0mAEBPu3VTAEABAAAaLgCjqvIq//Xm3M2zTvf8dummAPThzbmbZ62b5b9MAAAg5AQAutwx79l6yFEA7w8UAACgB54ECMACcsEEAAAodQIA0C5/EhlMAKAobYdX7uE4M7d633IfZazz/wAKAFN4c+7rngVAMsGvCFgnUADAFKCg3X8TfxLZWQUdFAAPQ4r1SiIgfNa56J1/St8nq2OXyPvCOhnn5VHAGgAJ7tZz3P37k8iFsE56FDDQT2i7Kx7oggIACZWAqNf9TQFAAaBlb2xwh28XJWDcIJ/ka8D6wDQ8Cph+dox7th6a33BD0YvNkUAv/SE4XfxJ5NLLUTo3xsqDYAUA6KIIAKTEJQAAUAAAAAWAIr2x4WtJXHv3QCBI532QyrqAAgAAKAAAQJOGI5/6oEcRPg5Yuvnd+9e0+VHAkj9FkdJlMFlgAkAQr1/oeh9gPVAAABLcpXuGArTHkwDpncsARD3v0/nXyAETAEJ5/cKvCl2S3a3b/VsHUACAYCVA+IMCQBAeCqQERAp/5zsp8MeAgNZKwDgfD7Trh24NXlt/k7s/gjvlzz9LZjfiZsBCd7yF/0nkXHf/rv+bAAB0MhEA0uEeAAAIaPDaBS4BUFWnPOUyALQtqfH/euN/EwAAIN4E4NULbjQBoKqqqjr1qZ+bAkCA3f9r62/y/sIEAAAUALBbAuczCgCxGAuC9zkKANg1gfMYBQC7A8D7GwUA7J7A+YsCAAAoAGQutTGhXRR2/+W9r+nfsPIYIDJZTD0cCOE/BWs9xxQAZwWL7RYuuHH21L/8ws4bCnk/Owos5BIAdlXgPEUBALsG8D4mgqELAOS2u3IvAHb/9VnjMQFgIq8muHswYkX45/v+RQEAJQDnIygAmAIA3rcoAGDXhfMQFADsJiy+OP/s/lEAQAnAeQdT8ihg6u8qzr9x9rSnPR0QUn+fOgrUMXjlvOtVAMZy2tNp7nw8H4Dou/9Xz/ceoD6XALAog/MMBQDy3mVYnIl6ftn9owBgkVYCcF6BAkDM3YbFmkjnk90/kxgcdBMgUzj96bQXRjcGUnr4vyL8MQEAkwCcP6AAYPdhEafw88buHwUAi5ASgPAHBQCUAJwncHyDg+de5yZAGnH6X3+ZxcLpxkByD/9XzrveOYwJABYlOzyEPygAWJyUAIQ/KACgBOA8AAUAuxSLP5n+/u3+aZqbAGlNLjcFHuHmQMEv/DEBgICLlmmA8Pc+IpKh7T8cHQ4mAcI/JdZo2jJ42SUAWrYqs0sBRygCgr9vB+3+aZFLAFjECgsNhD/UmwCsu9YEgG4mAc/8yiQA4V8n/M+9zjmHAoASoAgQJfiFPwoASoAiQLDgF/50zT0AWOSChYzw974AEwBMAkwDBL/wRwEAJUAREPzCHwUAlABFQPALf4o1dAig+XBSBAQ/mABAwEmAiYDgt/NHAYDgJUAZEPrCnyQLwEvrrlEASMoZz9xb9KhXEYgZ/FVVVS+fe63fPQkVgHMUABIsAc/eG+J6rzIQ59r+y+uEPwoAKAHBy0C0G/qEPwoAKAFhy0DUu/iFPwoAKAGhCoGP7Ql/FABQAgovBcJe+KMAgBJQYEEQ8MIfBQAUARD8FMCfA8YiC85LFACw2ILzkQgGL51ztUsAZO2MZ3/tkgA9Bf81gh8TALAI47yDnCYAZ5sAUMgk4DmTADoK/3OEPwUUgBcVAApzpiJAS14S/BTEJQAs0uC8wgQATANA8GMCABZvnD9gAgCmAQh+UABAEUDwQ6ZcAsAiD84LTADANADBD0EKwGYFAEXgud8oAuGC/2rBjwLgMIAiIPghWgFYqwDAMUXgb4pAccF/tuAHBQAUAcEPCoACAIqA4IdwBeCfCgCM5SxlIFkvCn1QAEAREPyAAgDKgNAHFABQBAQ/KAAKACgDQh/iFYCvKADQSSG4TyGoHfibBT4oAKAMCH1AAQCFQOADDRSANQoAJFkK9pZTCl5cK+xBAQCKLQaCHhQAoMCCIOBBAQAAMrbCIQCAeIa2/wBgAgAARJgAVJUZAACYAAAACgAAoAAAAAUYugUAAEwAAAAFAABQAAAABQAAUAAAgEwMRz4GAAAmAACAAgAAKAAAgAIAAGTJo4ABwAQAAFAAAAAFAABQAAAABQAAyMWw8jEAADABAAACTADs/wHABAAAUAAAgBJ5FDAAmAAAAAoAAKAAAAAKAACQKU8CBAATAABAAQAAFAAAQAEAADI1HLkHEABMAAAABQAAUAAAAAUAAMiSJwECgAkAAKAAAAAKAACgAAAACgAAkIuhDwEAgAkAABBhAmAAAAAmAABAhAmAJwECgAkAAKAAAAAKAACgAAAACgAAoAAAAKnyKGAAMAEAABQAAKBIw5FrAABgAgAAKAAAgAIAACgAAIACAAAoAACAAgAApMKjgAHABAAAUAAAgCINK9cAAMAEAAAIMAGw/wcAEwAAQAEAABQAAEABAAAUAAAgEx4FDAAmAABAjAmAEQAAmAAAAAoAAKAAAAAKAACQJX8MCABMAAAABQAAUAAAgDJ4FDAAhCwAGgAAhOMSAAAoAACAAgAAKAAAgAIAACgAAIACAAAkyx8DAgATAAAgxASgGpkBAIAJAACgAAAACgAAoAAAAAoAAKAAAAAKAACgAAAACgAAoAAAAO35P5tC4W+qz0PKAAAAAElFTkSuQmCC';

Future<void> main(List<String> args) async {
  final bytes = args.isNotEmpty
      ? await File(args.first).readAsBytes()
      : await _loadLogoFromEnvironmentOrFallback();
  final decoded = image.decodeImage(bytes);
  if (decoded == null) {
    throw StateError('logo_url is not a supported image');
  }

  final minSide = math.min(decoded.width, decoded.height);
  if (minSide < 512) {
    throw StateError(
      'Logo is too small (${decoded.width}x${decoded.height}); shortest side '
      'must be at least 512px, recommended is 1024x1024 PNG.',
    );
  }

  final squared = _centerCropSquare(decoded);
  final canonical = image.copyResize(
    squared,
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

Future<Uint8List> _loadLogoFromEnvironmentOrFallback() async {
  final logoUrl = (Platform.environment['LOGO_URL'] ?? '').trim();
  final uri = Uri.tryParse(logoUrl);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
    stdout.writeln('LOGO_URL is empty or invalid; using built-in fallback icon.');
    return base64Decode(_fallbackLogoPngBase64);
  }

  try {
    return await _download(uri);
  } catch (error) {
    stdout.writeln('Logo download failed ($error); using built-in fallback icon.');
    return base64Decode(_fallbackLogoPngBase64);
  }
}

Future<Uint8List> _download(Uri uri) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final request = await client
        .getUrl(uri)
        .timeout(const Duration(seconds: 20));
    request.headers
      ..set(HttpHeaders.userAgentHeader, 'WhiteLabelBuild/1.0')
      ..set(HttpHeaders.acceptHeader, 'image/png,image/*');
    final response = await request.close().timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('HTTP ${response.statusCode}', uri: uri);
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

image.Image _centerCropSquare(image.Image source) {
  final rgba = source.convert(numChannels: 4);
  if (rgba.width == rgba.height) {
    return rgba;
  }

  final size = math.min(rgba.width, rgba.height);
  final x = ((rgba.width - size) / 2).round();
  final y = ((rgba.height - size) / 2).round();
  stdout.writeln(
    'Logo is not square (${rgba.width}x${rgba.height}); center-cropping to '
    '${size}x$size for app icons.',
  );
  return image.copyCrop(rgba, x: x, y: y, width: size, height: size);
}

Future<void> _saveAssets(image.Image logo, Directory assets) async {
  await assets.create(recursive: true);

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
