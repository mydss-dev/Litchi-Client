import 'dart:io';

/// Downloads a fixed-size payload through the local proxy and returns
/// the measured throughput in Mbps.
abstract final class SpeedTester {
  // 10 MB from Cloudflare's public speed test endpoint.
  static const _testUrl = 'https://speed.cloudflare.com/__down?bytes=10000000';

  /// Runs a download speed test through [proxyPort] (HTTP CONNECT proxy).
  ///
  /// Returns download speed in Mbps, or null if the test fails or times out.
  static Future<double?> testDownload(int proxyPort) async {
    HttpClient? client;
    try {
      client = HttpClient();
      client.findProxy = (uri) => 'PROXY 127.0.0.1:$proxyPort';
      client.connectionTimeout = const Duration(seconds: 10);

      final request = await client
          .getUrl(Uri.parse(_testUrl))
          .timeout(const Duration(seconds: 10));

      final response =
          await request.close().timeout(const Duration(seconds: 30));

      if (response.statusCode < 200 || response.statusCode >= 300) return null;

      final sw = Stopwatch()..start();
      int received = 0;

      await for (final chunk
          in response.timeout(const Duration(seconds: 30))) {
        received += chunk.length;
      }

      sw.stop();
      final seconds = sw.elapsedMilliseconds / 1000.0;
      if (seconds < 0.05 || received < 1024) return null;

      return (received * 8) / (seconds * 1_000_000); // Mbps
    } catch (_) {
      return null;
    } finally {
      client?.close(force: true);
    }
  }
}
