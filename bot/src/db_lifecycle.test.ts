import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

test('build groups are counted once and remain recoverable until finalized', {
  skip:
    Number(process.versions.node.split('.')[0]) === 22
      ? false
      : 'better-sqlite3 is installed for the production Node 22 runtime',
}, async () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'litchi-bot-db-'));
  process.env.DB_PATH = path.join(directory, 'bot.sqlite');
  process.env.KEY_ENCRYPTION_KEY = 'a'.repeat(64);

  const store = await import(`./db.js?lifecycle=${Date.now()}`);
  try {
    store.authorizeUser({ tgUserId: 1001, authorizedBy: 9001 });
    store.bindAuthorizedUser({
      appId: 'client_test',
      tgUserId: 1001,
      ossDomain: 'https://cdn.example.com',
      remoteConfigUrl: 'https://cdn.example.com/config.json',
      publicKey: 'public',
      privateKey: 'private',
    });
    const common = {
      appId: 'client_test',
      tgUserId: 1001,
      chatId: 1001,
      version: '1.2.3',
      status: 'queued',
    };
    store.createBuild({
      ...common,
      buildGroupId: 'group-a',
      requestId: 'request-windows',
      platform: 'windows',
    });
    store.createBuild({
      ...common,
      buildGroupId: 'group-a',
      requestId: 'request-android',
      platform: 'android',
    });
    store.createBuild({
      ...common,
      buildGroupId: 'group-b',
      requestId: 'request-macos',
      platform: 'macos',
    });

    assert.equal(store.countRecentBuilds('client_test', 24), 2);
    assert.equal(store.hasActiveBuildGroup('client_test'), true);
    assert.equal(store.listRecoverableBuilds().length, 3);

    store.markBuildGroupFinalized('group-a');
    assert.equal(store.hasActiveBuildGroup('client_test'), true);
    assert.equal(store.listRecoverableBuilds().length, 1);

    store.markBuildGroupFinalized('group-b');
    assert.equal(store.hasActiveBuildGroup('client_test'), false);
    assert.equal(store.listRecoverableBuilds().length, 0);

    assert.equal(store.revokeAuthorizedUser(1001), true);
    assert.equal(store.getAuthorizedUser(1001), undefined);
    store.authorizeUser({ tgUserId: 1001, authorizedBy: 9001 });
    assert.equal(
      store.getAuthorizedUser(1001)?.remote_config_url,
      'https://cdn.example.com/config.json',
    );
    const rebound = store.rebindAuthorizedUser({
      tgUserId: 1001,
      ossDomain: 'https://new.example.com',
      remoteConfigUrl: 'https://new.example.com/config.json',
    });
    assert.equal(
      rebound.remote_config_url,
      'https://new.example.com/config.json',
    );
    assert.equal(
      store.getAppForUser('client_test', 1001)?.remote_config_url,
      'https://new.example.com/config.json',
    );
  } finally {
    store.db.close();
    fs.rmSync(directory, { recursive: true, force: true });
  }
});
