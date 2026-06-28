import assert from 'node:assert/strict';
import test from 'node:test';

import { buildRunName } from './github.js';
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
