"""Upload a self-hosted Litchi release directory to Cloudflare R2."""

from __future__ import annotations

import mimetypes
import os
from pathlib import Path
import re
import sys
import urllib.parse
from urllib.parse import quote

import boto3
from botocore.config import Config

# Manifests that live at the bucket root: the client derives the update-manifest
# URL as the sibling of CONFIG_URL (which points at config.json).
# config.json is signed by the remote-config key; update.json is signed by the
# independent update-manifest key.
ROOT_MANIFESTS = {"config.json", "update.json"}

# Keep this many release versions' installers in R2. Older ones are deleted
# after each upload so the bucket doesn't grow without bound.
KEEP_RELEASES = 3


def required_env(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise RuntimeError(f"Missing {name}")
    return value


def cleanup_old_releases(client, bucket: str, keep: int = KEEP_RELEASES) -> None:
    """Delete package objects older than the newest `keep` versions.

    R2 has a finite quota; without this, every tagged release leaves its
    installers behind forever. The newest `keep` versions are retained so a
    client mid-upgrade can still finish downloading an older-but-recent package.
    """
    paginator = client.get_paginator("list_objects_v2")
    versioned = []  # (version_tuple, key)
    for page in paginator.paginate(Bucket=bucket):
        for obj in page.get("Contents", []):
            key = obj["Key"]
            name = key.rsplit("/", 1)[-1]
            if name in ROOT_MANIFESTS:
                continue
            match = re.search(r"(\d+)\.(\d+)\.(\d+)", name)
            if not match:
                continue
            version = tuple(int(part) for part in match.groups())
            versioned.append((version, key))

    if not versioned:
        return

    versions = sorted({version for version, _ in versioned}, reverse=True)
    keep_versions = set(versions[:keep])

    removed = 0
    for version, key in versioned:
        if version not in keep_versions:
            client.delete_object(Bucket=bucket, Key=key)
            removed += 1
            print(
                f"Deleted old release ({'.'.join(map(str, version))}): {key}"
            )
    if removed:
        print(
            f"Cleaned up {removed} old package(s); "
            f"keeping the newest {len(keep_versions)} version(s)."
        )


def main() -> None:
    files = [Path(value) for value in sys.argv[1:]]
    if not files:
        raise RuntimeError(
            "Provide config.json/update.json and at least one package file"
        )
    if any(not path.is_file() for path in files):
        raise RuntimeError("Every upload argument must be a file")
    manifests = [path.name for path in files if path.name in ROOT_MANIFESTS]
    if not manifests or len(files) < 2:
        raise RuntimeError(
            "Upload must contain config.json/update.json and at least one package"
        )

    account_id = required_env("R2_ACCOUNT_ID")
    access_key = required_env("R2_ACCESS_KEY_ID")
    secret_key = required_env("R2_SECRET_ACCESS_KEY")
    bucket = required_env("R2_BUCKET")
    base_url = required_env("DOWNLOAD_BASE_URL").rstrip("/")
    parsed = urllib.parse.urlparse(base_url)

    # The R2 object prefix is the path of DOWNLOAD_BASE_URL: a package uploaded
    # to key "<prefix>/<name>" is served at "<DOWNLOAD_BASE_URL>/<name>", which
    # is exactly the download URL publish_release.ps1 writes into the manifest.
    # There is deliberately no R2_PREFIX fallback — a prefix that disagreed with
    # the download URL would make every installer 404.
    prefix = parsed.path.strip("/")

    client = boto3.client(
        "s3",
        endpoint_url=f"https://{account_id}.r2.cloudflarestorage.com",
        aws_access_key_id=access_key,
        aws_secret_access_key=secret_key,
        region_name="auto",
        config=Config(signature_version="s3v4"),
    )

    for path in files:
        # Manifests always go to the bucket root, because the client derives
        # their URL as the sibling of CONFIG_URL
        # (configUrl.resolve(name)). Package files go under the prefix.
        if path.name in ROOT_MANIFESTS:
            object_key = path.name
        else:
            object_key = f"{prefix}/{path.name}" if prefix else path.name
        content_type = mimetypes.guess_type(path.name)[0] or "application/octet-stream"
        extra = {"ContentType": content_type}
        if path.name in ROOT_MANIFESTS:
            # Short TTL so new releases are visible quickly.
            extra["CacheControl"] = "no-cache, max-age=300"
        else:
            extra["CacheControl"] = "public, max-age=86400"
            extra["ContentDisposition"] = (
                f"attachment; filename*=UTF-8''{quote(path.name)}"
            )
        client.upload_file(str(path), bucket, object_key, ExtraArgs=extra)
        # Print the URL a client actually downloads from. Packages are served at
        # "<DOWNLOAD_BASE_URL>/<name>"; manifests sit at the bucket root.
        if path.name in ROOT_MANIFESTS:
            display_url = f"{parsed.scheme}://{parsed.netloc}/{path.name}"
        else:
            display_url = f"{base_url}/{quote(path.name)}"
        print(f"Uploaded {path.name}: {display_url}")

    cleanup_old_releases(client, bucket)


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"R2 upload failed: {error}", file=sys.stderr)
        raise
