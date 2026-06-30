import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

import { buildRunName } from './github.js';
import {
  clearPendingAction,
  getPendingAction,
  setPendingAction,
} from './flow_state.js';
import {
  generateKeyPair,
  matchesPublishedVersion,
  signConfigPayload,
  verifyConfigPayload,
  withConfigVersion,
  withPreservedUpdateMetadata,
  withReleaseMetadata,
} from './signer.js';
import { parseAndValidateConfig, parseLooseConfig } from './validate.js';

test('build run names include the unique request id', () => {
  assert.equal(
    buildRunName({
      appId: 'client_123',
      platform: 'android',
      version: '1.2.7',
      requestId: 'request-abc',
    }),
    'client_123 android v1.2.7 [request-abc]',
  );
});

test('config validation rejects shell-friendly control characters', () => {
  assert.throws(
    () =>
      parseAndValidateConfig(
        JSON.stringify({
          app_name: 'Safe name\nmalicious-output=value',
          api_base_list: ['https://api.example.com'],
        }),
      ),
    /控制字符/,
  );
});

test('config validation accepts a normal signed-config payload', () => {
  assert.deepEqual(
    parseAndValidateConfig(
      JSON.stringify({
        app_name: 'Customer Client',
        logo_url: 'https://cdn.example.com/logo.png',
        api_base_list: ['https://api.example.com/'],
      }),
    ),
    {
      app_name: 'Customer Client',
      logo_url: 'https://cdn.example.com/logo.png',
      api_base_list: ['https://api.example.com'],
    },
  );
});

test('sample config leaves generated update metadata empty', () => {
  const sample = fs.readFileSync(
    new URL('../config.sample.json', import.meta.url),
    'utf8',
  );
  const config = parseAndValidateConfig(sample);
  assert.equal(config.update_version, '');
  assert.equal(config.update_download_url, '');
  assert.equal(config.update_sha256, '');
});

test('the JS template is valid and leaves release metadata to the bot', () => {
  const template = fs.readFileSync(
    new URL('../config.template.js', import.meta.url),
    'utf8',
  );
  const config = parseAndValidateConfig(template);
  assert.equal(config.app_name, '示例加速器');
  assert.equal(config.update_enabled, true);
  assert.equal('update_version' in config, false);
});

test('signing injects a monotonic config version owned by the bot', () => {
  const payload = {
    app_name: 'Customer Client',
    api_base_list: ['https://api.example.com'],
  };
  assert.deepEqual(withConfigVersion(payload, 7), {
    ...payload,
    config_version: 7,
  });
  assert.equal('config_version' in payload, false);
  assert.throws(() => withConfigVersion(payload, 0), /positive safe integer/);
  assert.throws(
    () =>
      parseAndValidateConfig(
        JSON.stringify({ ...payload, config_version: 99 }),
      ),
  );
});

test('saved configs can be verified and merged with build metadata', () => {
  const keys = generateKeyPair();
  const signed = signConfigPayload(
    withConfigVersion(
      {
        app_name: 'Customer Client',
        logo_url: 'https://cdn.example.com/logo.png',
        api_base_list: ['https://api.example.com'],
        update_version: '2.0.0',
        update_download_url: { windows: 'https://cdn.example.com/windows.exe' },
        update_sha256: { windows: 'a'.repeat(64) },
      },
      3,
    ),
    keys.privateKey,
  );
  const verified = verifyConfigPayload(JSON.stringify(signed), keys.publicKey);
  const merged = withReleaseMetadata(verified, [
    {
      platform: 'android',
      version: '2.0.0',
      downloadUrl: 'https://cdn.example.com/android.apk',
      sha256: 'b'.repeat(64),
    },
  ]);

  assert.equal('config_version' in merged, false);
  assert.deepEqual(merged.update_download_url, {
    windows: 'https://cdn.example.com/windows.exe',
    android: 'https://cdn.example.com/android.apk',
  });
  assert.deepEqual(merged.update_sha256, {
    windows: 'a'.repeat(64),
    android: 'b'.repeat(64),
  });
});

test('disabled update prompts still retain real package metadata', () => {
  assert.deepEqual(
    withReleaseMetadata(
      {
        app_name: 'Customer Client',
        update_enabled: false,
        update_version: '1.0.0',
        update_download_url: { windows: 'https://cdn.example.com/old.exe' },
        update_sha256: { windows: 'a'.repeat(64) },
      },
      [
        {
          platform: 'android',
          version: '2.0.0',
          downloadUrl: 'https://cdn.example.com/android.apk',
          sha256: 'b'.repeat(64),
        },
      ],
    ),
    {
      app_name: 'Customer Client',
      update_enabled: false,
      update_version: '2.0.0',
      update_download_url: {
        android: 'https://cdn.example.com/android.apk',
      },
      update_sha256: { android: 'b'.repeat(64) },
    },
  );
});

test('config-only changes preserve the last published package metadata', () => {
  const previous = {
    app_name: 'Old name',
    update_enabled: true,
    update_version: '2.0.0',
    update_download_url: { windows: 'https://cdn.example.com/windows.exe' },
    update_sha256: { windows: 'a'.repeat(64) },
    config_version: 4,
  };
  assert.deepEqual(
    withPreservedUpdateMetadata(
      {
        app_name: 'New name',
        update_enabled: true,
        update_version: '999.0.0',
        update_download_url: 'https://untrusted.example.com/file.exe',
        update_sha256: 'b'.repeat(64),
      },
      previous,
    ),
    {
      app_name: 'New name',
      update_enabled: true,
      update_version: '2.0.0',
      update_download_url: { windows: 'https://cdn.example.com/windows.exe' },
      update_sha256: { windows: 'a'.repeat(64) },
    },
  );
});

test('config-only changes preserve package metadata when prompts are disabled', () => {
  assert.deepEqual(
    withPreservedUpdateMetadata(
      { app_name: 'New name', update_enabled: false },
      {
        update_version: '2.0.0',
        update_download_url: 'https://cdn.example.com/file.exe',
        update_sha256: 'a'.repeat(64),
      },
    ),
    {
      app_name: 'New name',
      update_enabled: false,
      update_version: '2.0.0',
      update_download_url: 'https://cdn.example.com/file.exe',
      update_sha256: 'a'.repeat(64),
    },
  );
});

test('the stored package version decides whether another build is required', () => {
  assert.equal(matchesPublishedVersion({}, '2.0.0'), false);
  assert.equal(
    matchesPublishedVersion({ update_version: '1.9.0' }, '2.0.0'),
    false,
  );
  assert.equal(
    matchesPublishedVersion({ update_version: '2.0.0' }, '2.0.0'),
    true,
  );
});

test('same-version choice keeps the signed config until the user decides', () => {
  const userId = 9_001;
  const pending = {
    type: 'same_version_choice' as const,
    signedConfig: '{"payload_b64":"test","signature":"test"}',
    remoteConfigUrl: 'https://cdn.example.com/config.json',
    targetVersion: '2.0.0',
  };
  setPendingAction(userId, pending);
  assert.deepEqual(getPendingAction(userId), pending);
  clearPendingAction(userId);
  assert.equal(getPendingAction(userId), undefined);
});

test('update switch accepts only a boolean', () => {
  assert.throws(
    () =>
      parseAndValidateConfig(
        JSON.stringify({
          app_name: 'Customer Client',
          logo_url: 'https://cdn.example.com/logo.png',
          api_base_list: ['https://api.example.com'],
          update_enabled: 'yes',
        }),
      ),
    /true.*false/,
  );
});

test('config validation requires SHA-256 when updates are enabled', () => {
  assert.throws(
    () =>
      parseAndValidateConfig(
        JSON.stringify({
          app_name: 'Customer Client',
          logo_url: 'https://cdn.example.com/logo.png',
          api_base_list: ['https://api.example.com'],
          update_version: '2.0.0',
          update_download_url: 'https://cdn.example.com/setup.exe',
        }),
      ),
    /update_sha256/,
  );
});

test('config validation accepts matching platform update hashes', () => {
  const hash = 'a'.repeat(64);
  const config = parseAndValidateConfig(
    JSON.stringify({
      app_name: 'Customer Client',
      logo_url: 'https://cdn.example.com/logo.png',
      api_base_list: ['https://api.example.com'],
      update_version: '2.0.0',
      update_download_url: {
        windows: 'https://cdn.example.com/setup.exe',
        macos: 'https://cdn.example.com/setup.dmg',
      },
      update_sha256: { windows: hash, macos: hash },
    }),
  );

  assert.deepEqual(config.update_sha256, {
    windows: hash,
    macos: hash,
  });
});

test('config validation requires a logo URL', () => {
  assert.throws(
    () =>
      parseAndValidateConfig(
        JSON.stringify({
          app_name: 'Customer Client',
          api_base_list: ['https://api.example.com'],
        }),
      ),
    /logo_url/,
  );
});

test('config.js object-literal syntax still parses without executing code', () => {
  const value = parseLooseConfig(
    `const payload = {
      app_name: 'Customer Client', // unquoted key + single quotes + comment
      api_base_list: ['https://api.example.com',],
    };`,
  ) as Record<string, unknown>;
  assert.equal(value.app_name, 'Customer Client');
  assert.deepEqual(value.api_base_list, ['https://api.example.com']);
});

test('malicious config payload cannot execute code on the host', () => {
  const marker = '__litchi_pwned__';
  delete (globalThis as Record<string, unknown>)[marker];

  const payloads = [
    `{ x: (() => { globalThis['${marker}'] = true; return 1; })() }`,
    `{ x: ({}).constructor.constructor('globalThis["${marker}"]=true')() }`,
    '{ x: process.env }',
    '{ x: `${1 + 1}` }',
  ];

  for (const payload of payloads) {
    // Either the parser rejects it outright (preferred) or returns inert data,
    // but under no circumstance may the embedded expression run.
    try {
      parseLooseConfig(payload);
    } catch {
      // expected for expression syntax that is not valid JSON5
    }
    assert.equal(
      (globalThis as Record<string, unknown>)[marker],
      undefined,
      `payload executed code: ${payload}`,
    );
  }
});
