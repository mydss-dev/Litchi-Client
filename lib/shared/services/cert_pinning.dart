import 'dart:io';

import 'package:crypto/crypto.dart';

import '../config/app_config.dart';
import 'secure_logger.dart';

/// TLS certificate pinning hook.
///
/// Activated only when [AppConfig.certPinsSha256] is non-empty, so the default
/// build keeps standard CA validation and changes no behaviour.
///
/// Scope / limitation: dart:io's only TLS hook is [HttpClient.badCertificateCallback],
/// which fires when a certificate FAILS default validation. This lets us accept
/// a pinned self-signed / private-CA certificate, and surfaces a pin mismatch.
/// It does NOT reject a certificate that passes default validation but is signed
/// by an unexpected (e.g. rogue) public CA — defeating that requires a custom
/// [SecurityContext] limited to the pinned CA, or a native TLS layer. Provide
/// pins to enable the former; the latter is tracked as follow-up hardening.
abstract final class CertPinning {
  static bool get enabled => AppConfig.certPinsSha256.isNotEmpty;

  static Set<String> get _pins => AppConfig.certPinsSha256
      .map((p) => p.toLowerCase().replaceAll(':', '').trim())
      .toSet();

  /// [HttpClient.badCertificateCallback] implementation: accept an otherwise-
  /// rejected cert only when its SHA-256 matches a configured pin.
  static bool allowBadCertificate(X509Certificate cert, String host, int port) {
    if (!enabled) return false;
    final digest = sha256.convert(cert.der).toString().toLowerCase();
    final ok = _pins.contains(digest);
    if (!ok) {
      SecureLogger.warn('TLS cert pin mismatch for $host:$port');
    }
    return ok;
  }

  /// Installs the pinning callback on [client]. No-op when pinning is disabled.
  static void apply(HttpClient client) {
    if (!enabled) return;
    client.badCertificateCallback = allowBadCertificate;
  }
}
