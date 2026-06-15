import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/config/app_config.dart';
import 'package:litchi_client/shared/models/api_models.dart';
import 'package:litchi_client/shared/services/secure_logger.dart';
import 'package:litchi_client/shared/services/subscription_data_service.dart';
import 'package:litchi_client/shared/services/subscription_parser.dart';

void main() {
  test('redacts bearer tokens and proxy uris', () {
    final redacted = SecureLogRedactor.redact(
      'Authorization: Bearer abc.def token vmess://secret-node',
    );

    expect(redacted, isNot(contains('abc.def')));
    expect(redacted, isNot(contains('vmess://secret-node')));
    expect(redacted, contains('[REDACTED]'));
  });

  test('redacts account emails and sensitive query parameters', () {
    final redacted = SecureLogRedactor.redact(
      'user@example.com https://api.example.com/sub?token=abc123&uuid=node-id',
    );

    expect(redacted, isNot(contains('user@example.com')));
    expect(redacted, isNot(contains('abc123')));
    expect(redacted, isNot(contains('node-id')));
    expect(redacted, contains('token=[REDACTED]'));
    expect(redacted, contains('uuid=[REDACTED]'));
  });

  test('redacts core config style fields before log export', () {
    final redacted = SecureLogRedactor.redact(
      '{"server":"1.2.3.4","password":"secret"} trojan://secret@example.com',
    );

    expect(redacted, isNot(contains('1.2.3.4')));
    expect(redacted, isNot(contains('secret@example.com')));
    expect(redacted, contains('"server":[REDACTED]'));
    expect(redacted, contains('"password":[REDACTED]'));
  });

  test('rejects oversized subscription payloads', () {
    final body = 'a' * (SubscriptionParser.maxBodyBytes + 1);

    expect(SubscriptionParser.parse(body), isEmpty);
  });

  test('caps parsed uri list size', () {
    final lines = List.filled(
      SubscriptionParser.maxNodes + 5,
      'trojan://password@example.com:443#node',
    ).join('\n');

    expect(
      SubscriptionParser.parse(lines),
      hasLength(SubscriptionParser.maxNodes),
    );
  });

  test('maps subscription traffic header into app traffic model', () {
    final traffic = SubscriptionDataService.trafficFromSubTraffic(
      const SubTraffic(
        upload: AppConfig.bytesPerGb,
        download: AppConfig.bytesPerGb,
        total: 10 * AppConfig.bytesPerGb,
      ),
    );

    expect(traffic, isNotNull);
    expect(traffic!.totalGb, 10);
    expect(traffic.usedGb, 2);
    expect(traffic.remainGb, 8);
  });
}
