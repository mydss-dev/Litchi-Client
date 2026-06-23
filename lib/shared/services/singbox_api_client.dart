import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'singbox_config.dart';

/// Clash-compatible REST API client for sing-box runtime control.
///
/// sing-box exposes the same REST surface as Clash's external-controller,
/// so any operation that works against Clash's API works here identically.
///
/// Reference: https://sing-box.sagernet.org/configuration/experimental/clash-api/
abstract final class SingboxApiClient {
  static const String _selectorGroup = SingboxConfig.selectorTag;

  /// Switch the active outbound inside the running sing-box process.
  ///
  /// [tag]     — the outbound tag to activate (must exist in the running config).
  /// [apiPort] — Clash API port (default 9090).
  ///
  /// Returns true on success, false if the request fails (e.g. core not yet
  /// ready) — callers should treat false as a no-op, not an error.
  static Future<bool> switchProxy(String tag, {int apiPort = 9090}) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    try {
      final request = await client.putUrl(
        Uri.parse('http://127.0.0.1:$apiPort/proxies/$_selectorGroup'),
      );
      request.headers.contentType = ContentType.json;
      request.headers.add('Authorization', 'Bearer ${SingboxConfig.apiSecret}');
      request.write(jsonEncode({'name': tag}));

      final response = await request.close();
      await response.drain<void>();

      // 204 No Content = success per Clash API spec.
      return response.statusCode == 204;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }

  /// Test the round-trip latency of a specific outbound via sing-box.
  ///
  /// [tag]     — the outbound tag to test.
  /// [testUrl] — URL that sing-box will request through this outbound.
  /// [apiPort] — Clash API port.
  ///
  /// Returns latency in ms, or null if unreachable / core not running.
  static Future<int?> testDelay(
    String tag, {
    String? testUrl,
    int timeout = 5000,
    int apiPort = 9090,
  }) async {
    final url = testUrl ?? SingboxConfig.delayTestUrl;
    final uri = Uri.parse(
      'http://127.0.0.1:$apiPort/proxies/'
      '${Uri.encodeComponent(tag)}/delay'
      '?url=${Uri.encodeComponent(url)}&timeout=$timeout',
    );
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    try {
      final request = await client.getUrl(uri);
      request.headers.add('Authorization', 'Bearer ${SingboxConfig.apiSecret}');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) return null;
      final json = jsonDecode(body) as Map<String, dynamic>;
      return (json['delay'] as num?)?.toInt();
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  /// Patch the running core's mode (rule / global / direct) via Clash API.
  ///
  /// [clashMode] must be one of: 'rule', 'global', 'direct'.
  /// Returns true on success (204 No Content).
  static Future<bool> setMode(String clashMode, {int apiPort = 9090}) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    try {
      final request = await client.patchUrl(
        Uri.parse('http://127.0.0.1:$apiPort/configs'),
      );
      request.headers.contentType = ContentType.json;
      request.headers.add('Authorization', 'Bearer ${SingboxConfig.apiSecret}');
      request.write(jsonEncode({'mode': clashMode}));
      final response = await request.close();
      await response.drain<void>();
      return response.statusCode == 204;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }

  /// Subscribe to the sing-box traffic stream and emit upload/download rates.
  ///
  /// The endpoint sends a JSON object roughly once per second:
  ///   `{"up": N, "down": N}` (bytes/second)
  ///
  /// Cancel the subscription to close the underlying HTTP connection.
  static Stream<({int upBps, int downBps})> trafficStream({
    int apiPort = 9090,
  }) {
    final controller = StreamController<({int upBps, int downBps})>();
    HttpClient? httpClient;

    controller.onCancel = () => httpClient?.close(force: true);

    unawaited(() async {
      httpClient = HttpClient()..connectionTimeout = const Duration(seconds: 3);
      try {
        final request = await httpClient!.getUrl(
          Uri.parse('http://127.0.0.1:$apiPort/traffic'),
        );
        request.headers.add(
          'Authorization',
          'Bearer ${SingboxConfig.apiSecret}',
        );
        final response = await request.close();
        await for (final line
            in response
                .transform(utf8.decoder)
                .transform(const LineSplitter())) {
          if (controller.isClosed) break;
          try {
            final data = jsonDecode(line) as Map<String, dynamic>;
            controller.add((
              upBps: (data['up'] as num?)?.toInt() ?? 0,
              downBps: (data['down'] as num?)?.toInt() ?? 0,
            ));
          } catch (_) {}
        }
      } catch (_) {
      } finally {
        httpClient?.close();
        if (!controller.isClosed) unawaited(controller.close());
      }
    }());

    return controller.stream;
  }

  /// Fetch the current proxy state from the running core.
  ///
  /// Returns the raw JSON map or null if the core is not reachable.
  static Future<Map<String, dynamic>?> getProxies({int apiPort = 9090}) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    try {
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:$apiPort/proxies'),
      );
      request.headers.add('Authorization', 'Bearer ${SingboxConfig.apiSecret}');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) return null;
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  /// Trigger the urltest group (自动选择) to re-test all nodes, then return
  /// a map of outbound tag → latest delay in ms for every node that responded.
  ///
  /// If the urltest history is empty, falls back to direct per-node delay calls.
  /// This is slower, but much more reliable for manual "测速" button clicks.
  static Future<Map<String, int>> testAllViaUrltest({
    required List<String> tags,
    int apiPort = 9090,
    int timeout = 10000,
  }) async {
    // 1. Trigger the urltest group — blocks until all member tests finish.
    await testDelay(
      SingboxConfig.autoSelectTag,
      timeout: timeout,
      apiPort: apiPort,
    );

    // 2. Read the updated history for every proxy in one call.
    final results = await _readDelayHistory(apiPort: apiPort);
    if (results.isNotEmpty) return results;

    // 3. Fallback: test each node directly. Keep concurrency limited so the
    // local API and remote network are not overloaded.
    return _testDirect(tags, apiPort: apiPort, timeout: timeout);
  }

  static Future<Map<String, int>> _readDelayHistory({
    required int apiPort,
  }) async {
    final data = await getProxies(apiPort: apiPort);
    if (data == null) return {};

    final proxies = data['proxies'] as Map<String, dynamic>?;
    if (proxies == null) return {};

    final results = <String, int>{};
    proxies.forEach((tag, value) {
      if (value is! Map<String, dynamic>) return;
      final history = value['history'] as List?;
      if (history == null || history.isEmpty) return;
      final last = history.last as Map<String, dynamic>?;
      final delay = last?['delay'];
      if (delay is int && delay > 0) results[tag] = delay;
    });
    return results;
  }

  static Future<Map<String, int>> _testDirect(
    List<String> tags, {
    required int apiPort,
    required int timeout,
  }) async {
    final results = <String, int>{};
    const concurrency = 4;

    for (var i = 0; i < tags.length; i += concurrency) {
      final chunk = tags.skip(i).take(concurrency).toList();
      final values = await Future.wait(
        chunk.map((tag) async {
          final delay = await testDelay(
            tag,
            apiPort: apiPort,
            timeout: timeout,
          );
          return MapEntry(tag, delay);
        }),
      );
      for (final entry in values) {
        final delay = entry.value;
        if (delay != null && delay > 0) results[entry.key] = delay;
      }
    }

    return results;
  }
}
