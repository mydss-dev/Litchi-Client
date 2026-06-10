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
  static const String _selectorGroup = 'PROXY';

  /// Switch the active outbound inside the running sing-box process.
  ///
  /// [tag]     — the outbound tag to activate (must exist in the running config).
  /// [apiPort] — Clash API port (default 9090).
  ///
  /// Returns true on success, false if the request fails (e.g. core not yet
  /// ready) — callers should treat false as a no-op, not an error.
  static Future<bool> switchProxy(String tag, {int apiPort = 9090}) async {
    try {
      final client  = HttpClient();
      client.connectionTimeout = const Duration(seconds: 2);

      final request = await client.putUrl(
          Uri.parse('http://127.0.0.1:$apiPort/proxies/$_selectorGroup'));
      request.headers.contentType = ContentType.json;
      request.headers.add('Authorization', 'Bearer ${SingboxConfig.apiSecret}');
      request.write(jsonEncode({'name': tag}));

      final response = await request.close();
      await response.drain<void>();
      client.close();

      // 204 No Content = success per Clash API spec.
      return response.statusCode == 204;
    } catch (_) {
      return false;
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
    String testUrl = 'http://www.gstatic.com/generate_204',
    int    timeout = 5000,
    int    apiPort = 9090,
  }) async {
    try {
      final uri = Uri.parse(
        'http://127.0.0.1:$apiPort/proxies/'
        '${Uri.encodeComponent(tag)}/delay'
        '?url=${Uri.encodeComponent(testUrl)}&timeout=$timeout',
      );

      final client  = HttpClient();
      client.connectionTimeout = const Duration(seconds: 3);
      final request  = await client.getUrl(uri);
      request.headers.add('Authorization', 'Bearer ${SingboxConfig.apiSecret}');
      final response = await request.close();
      final body     = await response.transform(utf8.decoder).join();
      client.close();

      if (response.statusCode != 200) return null;
      final json = jsonDecode(body) as Map<String, dynamic>;
      return (json['delay'] as num?)?.toInt();
    } catch (_) {
      return null;
    }
  }

  /// Fetch the current proxy state from the running core.
  ///
  /// Returns the raw JSON map or null if the core is not reachable.
  static Future<Map<String, dynamic>?> getProxies({int apiPort = 9090}) async {
    try {
      final client   = HttpClient();
      client.connectionTimeout = const Duration(seconds: 2);
      final request  = await client.getUrl(
          Uri.parse('http://127.0.0.1:$apiPort/proxies'));
      request.headers.add('Authorization', 'Bearer ${SingboxConfig.apiSecret}');
      final response = await request.close();
      final body     = await response.transform(utf8.decoder).join();
      client.close();
      if (response.statusCode != 200) return null;
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
