import assert from 'node:assert/strict';
import test from 'node:test';

import { buildRunName } from './github.js';
import { parseAndValidateConfig } from './validate.js';

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
