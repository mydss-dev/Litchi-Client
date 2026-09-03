import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'sing_box_config.dart';
import 'secure_logger.dart';

/// REST/WebSocket client for sing-box's Clash-compatible controller.
abstract final class ClashApiClient {
  // ── shared client for short controller calls ──────────────────────────────
  static HttpClient? _client;

  /// Bearer secret of the running main core's clash_api. The owning
  /// CoreController keeps this session secret stable across process/reload
  /// transitions and mirrors it here before requests are made.
  static String apiSecret = '';

  static HttpClient get _sharedClient {
    final existing = _client;
    if (existing != null) return existing;
    final created = HttpClient()
      ..connectionTimeout = const Duration(seconds: 3)
      ..idleTimeout = const Duration(seconds: 15);
    _client = created;
    return created;
  }

  /// Drop idle connections to a controller that was stopped or reloaded.
  ///
  /// Transport reset and authentication lifetime are deliberately separate:
  /// clearing the session secret here used to make stop -> start transitions
  /// probe a correctly authenticated controller without its Bearer token.
  static void resetClient() {
    _client?.close(force: true);
    _client = null;
  }

  /// Explicitly ends the controller authentication session.
  static void clearSession() {
    resetClient();
    apiSecret = '';
  }

  static Future<bool> isReady({int apiPort = 9090}) async {
    final data = await getProxies(apiPort: apiPort);
    return data?['proxies'] is Map;
  }

  static Future<bool> switchProxy(
    String tag, {
    String group = SingBoxConfig.selectorTag,
    int apiPort = 9090,
  }) async {
    final response = await _request(
      'PUT',
      '/proxies/${Uri.encodeComponent(group)}',
      apiPort: apiPort,
      body: {'name': tag},
    );
    return response?.statusCode == 204;
  }

  static Future<int?> testDelay(
    String tag, {
    String? testUrl,
    int timeout = 5000,
    int apiPort = 9090,
  }) async {
    final query = Uri(
      queryParameters: {
        'url': testUrl ?? SingBoxConfig.delayTestUrl,
        'timeout': '$timeout',
        'expected': '200/204',
      },
    ).query;
    final response = await _request(
      'GET',
      '/proxies/${Uri.encodeComponent(tag)}/delay?$query',
      apiPort: apiPort,
    );
    if (response?.statusCode != 200) return null;
    final data = jsonDecode(response!.body) as Map<String, dynamic>;
    return (data['delay'] as num?)?.toInt();
  }

  /// Tests every member of the application's selector in one core operation.
  static Future<Map<String, int>> testGroup({
    String group = SingBoxConfig.selectorTag,
    int apiPort = 9090,
    int timeout = 5000,
  }) async {
    final query = Uri(
      queryParameters: {
        'url': SingBoxConfig.delayTestUrl,
        'timeout': '$timeout',
        'expected': '200/204',
      },
    ).query;
    final response = await _request(
      'GET',
      '/group/${Uri.encodeComponent(group)}/delay?$query',
      apiPort: apiPort,
    ).timeout(Duration(milliseconds: timeout + 1500), onTimeout: () => null);
    if (response?.statusCode != 200) return {};
    final data = jsonDecode(response!.body);
    if (data is! Map) return {};
    return {
      for (final entry in data.entries)
        if (entry.value is num && (entry.value as num) > 0)
          '${entry.key}': (entry.value as num).toInt(),
    };
  }

  /// Reloads the full configuration without restarting the process.
  /// Returns true when the API responds 204 (no content).
  static Future<bool> reloadConfig(
    String configJson, {
    int apiPort = 9090,
  }) async {
    final response = await _request(
      'PUT',
      '/configs',
      apiPort: apiPort,
      body: {'path': '', 'payload': configJson},
    );
    return response?.statusCode == 204;
  }

  static Future<bool> setMode(String mode, {int apiPort = 9090}) async {
    final response = await _request(
      'PATCH',
      '/configs',
      apiPort: apiPort,
      body: {'mode': mode},
    );
    if (response?.statusCode != 204) return false;
    return true;
  }

  static Future<bool> closeConnections({int apiPort = 9090}) async {
    final response = await _request('DELETE', '/connections', apiPort: apiPort);
    return response?.statusCode == 204;
  }

  static Stream<({int upBps, int downBps})> trafficStream({
    int apiPort = 9090,
  }) {
    final controller = StreamController<({int upBps, int downBps})>();
    HttpClient? client;
    controller.onCancel = () => client?.close(force: true);

    unawaited(() async {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
      try {
        final request = await client!.getUrl(
          Uri.parse('http://127.0.0.1:$apiPort/traffic'),
        );
        final secret = apiSecret;
        if (secret.isNotEmpty) {
          request.headers.set('Authorization', 'Bearer $secret');
        }
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
          } catch (_) {
            // intentional: parse attempt, fallback handled below
          }
        }
      } catch (e) {
        SecureLogger.debug('traffic stream error', e);
      } finally {
        client?.close();
        if (!controller.isClosed) unawaited(controller.close());
      }
    }());
    return controller.stream;
  }

  static Future<Map<String, dynamic>?> getProxies({int apiPort = 9090}) async {
    final response = await _request('GET', '/proxies', apiPort: apiPort);
    if (response?.statusCode != 200) return null;
    try {
      return jsonDecode(response!.body) as Map<String, dynamic>;
    } catch (_) {
      // intentional: parse attempt, fallback handled below
      return null;
    }
  }

  static Future<_ApiResponse?> _request(
    String method,
    String path, {
    required int apiPort,
    Map<String, dynamic>? body,
  }) async {
    try {
      final client = _sharedClient;
      final uri = Uri.parse('http://127.0.0.1:$apiPort$path');
      final request = switch (method) {
        'PUT' => await client.putUrl(uri),
        'PATCH' => await client.patchUrl(uri),
        'DELETE' => await client.deleteUrl(uri),
        _ => await client.getUrl(uri),
      };
      final secret = apiSecret;
      if (secret.isNotEmpty) {
        request.headers.set('Authorization', 'Bearer $secret');
      }
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      return _ApiResponse(response.statusCode, text);
    } catch (e) {
      SecureLogger.debug('Clash API request failed', e);
      return null;
    }
  }
}

class _ApiResponse {
  const _ApiResponse(this.statusCode, this.body);
  final int statusCode;
  final String body;
}
