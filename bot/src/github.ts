import { Octokit } from '@octokit/rest';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { env, repoParts } from './config.js';

export type BuildPlatform = 'windows' | 'android' | 'macos';

export type BuildStatusSnapshot = {
  githubRunUrl: string;
  status: string;
};

export async function dispatchBuild(input: {
  appId: string;
  platform: BuildPlatform;
  version: string;
  remoteConfigUrl: string;
  verifier: string;
}): Promise<string> {
  if (!env.githubToken) throw new Error('Missing GITHUB_TOKEN');

  const { owner, repo } = repoParts();
  const octokit = new Octokit({ auth: env.githubToken });

  await octokit.actions.createWorkflowDispatch({
    owner,
    repo,
    workflow_id: env.githubWorkflowId,
    ref: env.githubRef,
    inputs: {
      app_id: input.appId,
      platform: input.platform,
      version: input.version,
      remote_config_url: input.remoteConfigUrl,
      remote_config_verifier: input.verifier,
    },
  });

  return `https://github.com/${owner}/${repo}/actions/workflows/${env.githubWorkflowId}`;
}

export async function readBuildStatus(input: {
  appId: string;
  platform: string;
  version: string;
}): Promise<BuildStatusSnapshot | undefined> {
  if (!env.githubToken) return undefined;

  const { owner, repo } = repoParts();
  const octokit = new Octokit({ auth: env.githubToken });
  const expectedTitle = `${input.appId} ${input.platform} v${input.version}`;

  const response = await octokit.actions.listWorkflowRuns({
    owner,
    repo,
    workflow_id: env.githubWorkflowId,
    event: 'workflow_dispatch',
    per_page: 50,
  });

  const run = response.data.workflow_runs.find((item) => {
    const displayTitle =
      String((item as { display_title?: string }).display_title ?? '').trim();
    return displayTitle === expectedTitle;
  });

  if (!run?.html_url) return undefined;

  return {
    githubRunUrl: run.html_url,
    status: normalizeRunStatus(run.status, run.conclusion),
  };
}

export function getCurrentBuildVersion(): string {
  const envVersion = env.buildVersion.trim();
  if (envVersion) {
    return envVersion;
  }

  const pubspecPath = resolvePubspecPath();
  const content = fs.readFileSync(pubspecPath, 'utf8');
  const match = content.match(/^version:\s*([^\s+]+)/m);
  if (!match?.[1]) {
    throw new Error(`无法从 ${pubspecPath} 读取当前版本。`);
  }
  return match[1].trim();
}

function resolvePubspecPath(): string {
  const currentFile = fileURLToPath(import.meta.url);
  const currentDir = path.dirname(currentFile);

  const candidates = [
    env.buildVersionFile.trim(),
    path.resolve(currentDir, '../../pubspec.yaml'),
    path.resolve(currentDir, '../../../pubspec.yaml'),
    path.resolve(process.cwd(), 'pubspec.yaml'),
    path.resolve(process.cwd(), '../pubspec.yaml'),
    path.resolve(process.cwd(), '../../pubspec.yaml'),
  ].filter(Boolean);

  for (const candidate of candidates) {
    if (fs.existsSync(candidate) && fs.statSync(candidate).isFile()) {
      return candidate;
    }
  }

  throw new Error(
    [
      '找不到 pubspec.yaml。',
      '请在 .env 中配置 BUILD_VERSION=1.2.7',
      '或者配置 BUILD_VERSION_FILE=/app/pubspec.yaml',
    ].join('\n'),
  );
}

function normalizeRunStatus(
  status?: string | null,
  conclusion?: string | null,
): string {
  if (status && status !== 'completed') {
    return status;
  }
  if (conclusion === 'success') return 'success';
  if (conclusion === 'failure') return 'failed';
  if (conclusion === 'cancelled') return 'cancelled';
  if (conclusion === 'timed_out') return 'timed_out';
  if (conclusion === 'action_required') return 'action_required';
  if (conclusion === 'neutral') return 'neutral';
  if (conclusion === 'skipped') return 'skipped';
  return status ?? 'queued';
}
