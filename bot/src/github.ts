import { Octokit } from '@octokit/rest';
import { createHash } from 'node:crypto';
import { nanoid } from 'nanoid';

import { env, repoParts } from './config.js';

export type BuildPlatform = 'windows' | 'android' | 'macos';

export type BuildStatusSnapshot = {
  githubRunUrl: string;
  status: string;
  downloadUrl: string;
  sha256: string;
};

/// Returns the stable public identity used by build artifacts and client code.
/// It is derived from the per-app random signing key, never from Telegram IDs.
export function publicTenantId(publicKey: string): string {
  const digest = createHash('sha256')
    .update(publicKey.trim(), 'utf8')
    .digest('hex')
    .slice(0, 16);
  return `tenant_${digest}`;
}

export function buildRunName(input: {
  appId: string;
  platform: string;
  version: string;
  requestId: string;
}): string {
  return `${input.appId} ${input.platform} v${input.version} [${input.requestId}]`;
}

export async function dispatchBuild(input: {
  appId: string;
  nativeAppId: string;
  platform: BuildPlatform;
  version: string;
  remoteConfigUrl: string;
  verifier: string;
  signedConfig: string;
  requestId?: string;
}): Promise<{ requestId: string; workflowUrl: string; downloadUrl: string }> {
  if (!env.githubToken) throw new Error('Missing GITHUB_TOKEN');

  const { owner, repo } = repoParts();
  const octokit = new Octokit({ auth: env.githubToken });
  const requestId = input.requestId ?? nanoid(12);
  const signedConfigB64 = Buffer.from(input.signedConfig, 'utf8').toString(
    'base64',
  );
  if (signedConfigB64.length > 60_000) {
    throw new Error('签名配置过大，无法安全传入构建任务。');
  }
  const workflowInputs: Record<string, string> = {
    app_id: input.appId,
    native_app_id: input.nativeAppId,
    platform: input.platform,
    version: input.version,
    remote_config_url: input.remoteConfigUrl,
    remote_config_verifier: input.verifier,
    request_id: requestId,
    signed_config_b64: signedConfigB64,
  };
  if (env.downloadBaseUrl) {
    workflowInputs.download_base_url = env.downloadBaseUrl;
  }

  await octokit.actions.createWorkflowDispatch({
    owner,
    repo,
    workflow_id: env.githubWorkflowId,
    ref: env.githubRef,
    inputs: workflowInputs,
  });

  return {
    requestId,
    workflowUrl: `https://github.com/${owner}/${repo}/actions/workflows/${env.githubWorkflowId}`,
    downloadUrl: buildDownloadUrl({
      appId: input.appId,
      platform: input.platform,
      version: input.version,
      requestId,
    }),
  };
}

export async function readBuildStatus(input: {
  appId: string;
  platform: string;
  version: string;
  requestId: string;
}): Promise<BuildStatusSnapshot | undefined> {
  if (!env.githubToken) return undefined;

  const { owner, repo } = repoParts();
  const octokit = new Octokit({ auth: env.githubToken });
  const expectedTitle = buildRunName(input);

  const response = await octokit.actions.listWorkflowRuns({
    owner,
    repo,
    workflow_id: env.githubWorkflowId,
    event: 'workflow_dispatch',
    per_page: 100,
  });

  const run = response.data.workflow_runs.find((item) => {
    const displayTitle = String(
      (item as { display_title?: string }).display_title ?? '',
    ).trim();
    return displayTitle === expectedTitle;
  });

  if (!run?.html_url) return undefined;

  let r2UploadSucceeded = false;
  if (run.conclusion === 'success' && env.downloadBaseUrl) {
    const jobs = await octokit.actions.listJobsForWorkflowRun({
      owner,
      repo,
      run_id: run.id,
      per_page: 100,
    });
    r2UploadSucceeded = jobs.data.jobs.some((job) =>
      job.steps?.some(
        (step) =>
          step.name === 'Upload package to Cloudflare R2' &&
          step.conclusion === 'success',
      ),
    );
  }

  const downloadUrl = r2UploadSucceeded
    ? buildDownloadUrl({
        appId: input.appId,
        platform: input.platform,
        version: input.version,
        requestId: input.requestId,
      })
    : '';

  return {
    githubRunUrl: run.html_url,
    status: normalizeRunStatus(run.status, run.conclusion),
    downloadUrl,
    sha256: downloadUrl ? await readPublishedSha256(downloadUrl) : '',
  };
}

async function readPublishedSha256(url: string): Promise<string> {
  try {
    const response = await fetch(url, {
      method: 'HEAD',
      signal: AbortSignal.timeout(10_000),
    });
    if (response.ok) {
      const metadataHash =
        response.headers.get('x-amz-meta-sha256')?.trim().toLowerCase() ?? '';
      if (/^[a-f0-9]{64}$/.test(metadataHash)) return metadataHash;
    }
  } catch {
    // Some public R2/CDN setups do not expose S3 object metadata. Fall back
    // to the sidecar file uploaded with the package.
  }

  try {
    const response = await fetch(`${url}.sha256`, {
      signal: AbortSignal.timeout(10_000),
    });
    if (!response.ok) return '';
    const value = (await response.text()).trim().toLowerCase();
    return /^[a-f0-9]{64}$/.test(value) ? value : '';
  } catch {
    return '';
  }
}

export function buildDownloadUrl(input: {
  appId: string;
  platform: string;
  version: string;
  requestId: string;
}): string {
  if (!env.downloadBaseUrl) return '';
  const extension =
    input.platform === 'windows'
      ? 'exe'
      : input.platform === 'macos'
        ? 'dmg'
        : input.platform === 'android'
          ? 'apk'
          : '';
  if (!extension) return '';
  const segments = [
    'packages',
    input.appId,
    input.platform,
    input.version,
    `${input.requestId}.${extension}`,
  ].map(encodeURIComponent);
  return `${env.downloadBaseUrl}/${segments.join('/')}`;
}

export function getCurrentBuildVersion(): string {
  const version = env.buildVersion.trim();
  if (!version) {
    throw new Error('Missing BUILD_VERSION，请在 bot/.env 中填写，例如 1.2.7');
  }
  if (!/^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$/.test(version)) {
    throw new Error('BUILD_VERSION 格式不正确，应类似 1.2.7');
  }
  return version;
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
