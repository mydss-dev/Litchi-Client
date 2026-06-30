import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/config/app_config.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/shared/services/update_service.dart';

bool get _installerDownloadSupported => Platform.isWindows || Platform.isMacOS;

void main() {
  test('selects a URL and mandatory hash from update metadata', () {
    final originalVersion = AppConfig.currentVersion;
    addTearDown(() => AppConfig.currentVersion = originalVersion);
    AppConfig.currentVersion = '1.0.0';
    final hash = List.filled(64, 'a').join();
    AppConfig.applyRemote({
      'update_version': '2.0.0',
      'update_download_url': 'https://cdn.example.com/setup.exe',
      'update_sha256': hash,
    });

    final info = UpdateService.check();

    expect(info, isNotNull);
    expect(info!.downloadUrl, 'https://cdn.example.com/setup.exe');
    expect(info.sha256, hash);
  });

  test('does not advertise an update with invalid hash metadata', () {
    final originalVersion = AppConfig.currentVersion;
    addTearDown(() => AppConfig.currentVersion = originalVersion);
    AppConfig.currentVersion = '1.0.0';
    AppConfig.applyRemote({
      'update_version': '2.0.0',
      'update_download_url': 'https://cdn.example.com/setup.exe',
      'update_sha256': 'invalid',
    });

    expect(UpdateService.check(), isNull);
  });

  test('remote update switch disables an otherwise valid update', () {
    final originalVersion = AppConfig.currentVersion;
    final originalEnabled = AppConfig.updatesEnabled;
    addTearDown(() {
      AppConfig.currentVersion = originalVersion;
      AppConfig.updatesEnabled = originalEnabled;
    });
    AppConfig.currentVersion = '1.0.0';
    AppConfig.applyRemote({
      'update_enabled': false,
      'update_version': '2.0.0',
      'update_download_url': 'https://cdn.example.com/setup.exe',
      'update_sha256': List.filled(64, 'a').join(),
    });

    expect(UpdateService.check(), isNull);
  });

  test('UpdateInfo accepts only a complete hexadecimal SHA-256', () {
    expect(
      const UpdateInfo(
        version: '1',
        downloadUrl: 'https://example.com/update',
        sha256:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      ).hasHash,
      isTrue,
    );
    expect(
      const UpdateInfo(
        version: '1',
        downloadUrl: 'https://example.com/update',
      ).hasHash,
      isFalse,
    );
    expect(
      const UpdateInfo(
        version: '1',
        downloadUrl: 'https://example.com/update',
        sha256:
            'zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz',
      ).hasHash,
      isFalse,
    );
  });

  test('refuses a download when SHA-256 is missing', () async {
    const info = UpdateInfo(
      version: 'missing-hash-test',
      downloadUrl: 'https://example.com/update',
    );

    await expectLater(
      UpdateService.downloadVerifiedInstaller(info),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'streams a valid installer to disk and reports progress',
    () async {
      final payload = List<int>.generate(128 * 1024, (index) => index % 251);
      final server = await _serve(payload);
      addTearDown(() => server.close(force: true));
      var received = 0;
      var total = -1;
      final info = UpdateInfo(
        version: 'stream-test',
        downloadUrl: 'http://${server.address.host}:${server.port}/update',
        sha256: sha256.convert(payload).toString(),
      );

      final path = await UpdateService.downloadVerifiedInstaller(
        info,
        onProgress: (current, expected) {
          received = current;
          total = expected;
        },
      );
      final file = File(path);
      addTearDown(() async {
        if (await file.exists()) await file.delete();
      });

      expect(await file.readAsBytes(), payload);
      expect(received, payload.length);
      expect(total, payload.length);
    },
    skip: _installerDownloadSupported
        ? false
        : 'Installer download is desktop-only',
  );

  test(
    'deletes an installer whose SHA-256 does not match',
    () async {
      final payload = List<int>.filled(4096, 7);
      final server = await _serve(payload);
      addTearDown(() => server.close(force: true));
      final ext = Platform.isWindows ? '.exe' : '.dmg';
      final file = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}'
        'Client-Setup-hash-mismatch-test$ext',
      );
      if (await file.exists()) await file.delete();

      final info = UpdateInfo(
        version: 'hash-mismatch-test',
        downloadUrl: 'http://${server.address.host}:${server.port}/update',
        sha256: List.filled(64, '0').join(),
      );

      await expectLater(
        UpdateService.downloadVerifiedInstaller(info),
        throwsA(isA<Exception>()),
      );
      expect(await file.exists(), isFalse);
    },
    skip: _installerDownloadSupported
        ? false
        : 'Installer download is desktop-only',
  );
}

Future<HttpServer> _serve(List<int> payload) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    request.response.contentLength = payload.length;
    const chunkSize = 8192;
    for (var offset = 0; offset < payload.length; offset += chunkSize) {
      final end = (offset + chunkSize).clamp(0, payload.length);
      request.response.add(payload.sublist(offset, end));
    }
    await request.response.close();
  });
  return server;
}
