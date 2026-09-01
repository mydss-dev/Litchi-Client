import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import '../../config/app_config.dart';
import 'secure_logger.dart';

/// Resolves the cloud avatar to a session-stable, persistent local file.
///
/// Only the avatar is downloaded at runtime. The brand logo and tray icons are
/// baked into the bundle at build time (from the same signed config's
/// `logo_url`), so re-downloading the logo every launch would be redundant.
/// The avatar is fetched before `runApp` so widgets do not paint a stale
/// placeholder and then swap it out.
abstract final class BrandAssetCache {
  static const _timeout = Duration(seconds: 5);
  static const _maxBytes = 5 * 1024 * 1024;

  static File? avatarFile;

  /// The avatar URL is snapshotted for the whole process. A remote-config
  /// refresh is persisted for the next launch instead of changing the visible
  /// avatar halfway through the current session.
  static String avatarUrl = '';

  static Future<void> initialize() async {
    avatarUrl = _remoteUrl(AppConfig.avatarUrl);
    try {
      final support = await getApplicationSupportDirectory();
      final directory = Directory(
        '${support.path}${Platform.pathSeparator}brand',
      );
      await directory.create(recursive: true);
      final file = await _resolve(directory, 'avatar', avatarUrl);
      avatarFile = await _validateAndWarm(file);
    } catch (e) {
      SecureLogger.warn('Avatar cache initialization failed', e);
    }
  }

  static Future<File?> _resolve(
    Directory directory,
    String slot,
    String url,
  ) async {
    if (url.isEmpty) {
      await _pruneSlot(directory, slot, keep: null);
      return null;
    }
    final digest = sha256.convert(utf8.encode(url)).toString();
    final target = File(
      '${directory.path}${Platform.pathSeparator}${slot}_$digest.img',
    );
    if (await target.exists() && await target.length() > 0) {
      await _pruneSlot(directory, slot, keep: target);
      return target;
    }

    final temp = File('${target.path}.tmp');
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = _timeout;
      final request = await client.getUrl(Uri.parse(url)).timeout(_timeout);
      final response = await request.close().timeout(_timeout);
      if (response.statusCode != HttpStatus.ok) return null;
      final contentLength = response.contentLength;
      if (contentLength > _maxBytes) return null;

      final builder = BytesBuilder(copy: false);
      var length = 0;
      await for (final chunk in response.timeout(_timeout)) {
        length += chunk.length;
        if (length > _maxBytes) return null;
        builder.add(chunk);
      }
      if (length == 0) return null;
      await temp.writeAsBytes(builder.takeBytes(), flush: true);
      await temp.rename(target.path);
      await _pruneSlot(directory, slot, keep: target);
      return target;
    } catch (e) {
      SecureLogger.debug('Brand asset download failed for $slot', e);
      return null;
    } finally {
      client?.close(force: true);
      if (await temp.exists()) {
        try {
          await temp.delete();
        } catch (_) {
          // Best-effort cleanup.
        }
      }
    }
  }

  /// Decodes once before the first frame. [Image.file] then resolves from
  /// Flutter's in-memory image cache synchronously.
  static Future<File?> _validateAndWarm(File? file) async {
    if (file == null) return null;
    if (await _warmImageCache(file)) return file;
    try {
      await file.delete();
    } catch (_) {
      // Best-effort removal of a corrupt cache entry.
    }
    return null;
  }

  static Future<bool> _warmImageCache(File file) {
    final completer = Completer<bool>();
    late final ImageStreamListener listener;
    final stream = FileImage(file).resolve(ImageConfiguration.empty);
    listener = ImageStreamListener(
      (_, _) {
        stream.removeListener(listener);
        if (!completer.isCompleted) completer.complete(true);
      },
      onError: (_, _) {
        stream.removeListener(listener);
        if (!completer.isCompleted) completer.complete(false);
      },
    );
    stream.addListener(listener);
    return completer.future.timeout(
      _timeout,
      onTimeout: () {
        stream.removeListener(listener);
        return false;
      },
    );
  }

  static Future<void> _pruneSlot(
    Directory directory,
    String slot, {
    required File? keep,
  }) async {
    try {
      await for (final entry in directory.list()) {
        if (entry is! File || entry.path == keep?.path) continue;
        final name = entry.uri.pathSegments.last;
        if (name.startsWith('${slot}_') &&
            (name.endsWith('.img') || name.endsWith('.img.tmp'))) {
          await entry.delete();
        }
      }
    } catch (_) {
      // Best-effort cache size control.
    }
  }

  static String _remoteUrl(String value) {
    final trimmed = value.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      return '';
    }
    return trimmed;
  }
}
