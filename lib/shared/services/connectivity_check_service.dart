import 'dart:async';
import 'dart:io';

/// One reachability probe target. Endpoints answer with a fast 204/200 so
/// the probe measures tunnel reachability, not page weight.
class ConnectivityTarget {
  const ConnectivityTarget({required this.name, required this.url});

  final String name;
  final String url;
}

class ConnectivityResult {
  const ConnectivityResult({required this.ok, required this.latencyMs});

  final bool ok;

  /// Round-trip milliseconds to the first response bytes; -1 on failure.
  final int latencyMs;
}

/// Probes well-known sites through the current network path (system proxy,
/// TUN or direct), so a connected user can see whether the tunnel actually
/// reaches the services they care about. Pure HTTP against the live network:
/// no core API involved, so the results reflect exactly what the apps on
/// this machine experience.
abstract final class ConnectivityCheckService {
  /// Default probe set; names are shown in the UI as-is.
  static const List<ConnectivityTarget> defaultTargets = [
    ConnectivityTarget(name: 'Google', url: 'https://www.gstatic.com/generate_204'),
    ConnectivityTarget(name: 'YouTube', url: 'https://www.youtube.com/generate_204'),
    ConnectivityTarget(name: 'GitHub', url: 'https://github.com'),
    ConnectivityTarget(name: 'ChatGPT', url: 'https://chatgpt.com'),
  ];

  /// Test seam: when set, [probe] delegates here. Lets widget tests render
  /// real results without touching the network.
  static Future<ConnectivityResult> Function(ConnectivityTarget target)?
  override;

  static Future<ConnectivityResult> probe(
    ConnectivityTarget target, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (override != null) return override!(target);
    final client = HttpClient()..connectionTimeout = timeout;
    final watch = Stopwatch()..start();
    try {
      final request = await client.getUrl(Uri.parse(target.url)).timeout(
        timeout,
      );
      // Cloudflare-fronted sites (ChatGPT) reject the bare Dart UA with a
      // 403 challenge; a browser-shaped UA keeps the probe honest.
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Mozilla/5.0 (compatible; Litchi connectivity probe)',
      );
      final response = await request.close().timeout(timeout);
      await response.drain<void>().timeout(timeout);
      watch.stop();
      final ok = response.statusCode >= 200 && response.statusCode < 400;
      return ConnectivityResult(
        ok: ok,
        latencyMs: ok ? watch.elapsedMilliseconds : -1,
      );
    } catch (_) {
      // Unreachable is a valid answer, not an error to surface.
      return const ConnectivityResult(ok: false, latencyMs: -1);
    } finally {
      client.close(force: true);
    }
  }
}
