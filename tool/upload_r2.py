"""Upload one packaged build to Cloudflare R2 using its S3-compatible API."""

from __future__ import annotations

import mimetypes
import os
from pathlib import Path
import sys
from urllib.parse import quote

import boto3
from botocore.config import Config


def required_env(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise RuntimeError(f"Missing {name}")
    return value


def safe_segment(value: str, label: str) -> str:
    value = value.strip()
    if not value or any(char not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-+" for char in value):
        raise RuntimeError(f"Unsafe {label}")
    return value


def main() -> None:
    release_dir = Path(sys.argv[1] if len(sys.argv) > 1 else "release")
    files = [path for path in release_dir.iterdir() if path.is_file()]
    if len(files) != 1:
        raise RuntimeError(f"Expected exactly one package in {release_dir}, found {len(files)}")
    package = files[0]

    account_id = safe_segment(required_env("R2_ACCOUNT_ID"), "R2_ACCOUNT_ID")
    access_key = required_env("R2_ACCESS_KEY_ID")
    secret_key = required_env("R2_SECRET_ACCESS_KEY")
    bucket = required_env("R2_BUCKET")
    base_url = required_env("DOWNLOAD_BASE_URL").rstrip("/")
    tenant_id = safe_segment(required_env("TENANT_ID"), "TENANT_ID")
    platform = safe_segment(required_env("RUNNER_OS").lower(), "platform")
    requested_platform = {
        "windows": "windows",
        "macos": "macos",
        "linux": "android",
    }.get(platform)
    if requested_platform is None:
        raise RuntimeError(f"Unsupported runner platform: {platform}")
    version = safe_segment(required_env("BUILD_VERSION"), "BUILD_VERSION")
    request_id = safe_segment(required_env("REQUEST_ID"), "REQUEST_ID")
    extension = package.suffix.lower().lstrip(".")
    object_key = (
        f"packages/{tenant_id}/{requested_platform}/{version}/"
        f"{request_id}.{extension}"
    )

    client = boto3.client(
        "s3",
        endpoint_url=f"https://{account_id}.r2.cloudflarestorage.com",
        aws_access_key_id=access_key,
        aws_secret_access_key=secret_key,
        region_name="auto",
        config=Config(signature_version="s3v4"),
    )
    content_type = mimetypes.guess_type(package.name)[0] or "application/octet-stream"
    client.upload_file(
        str(package),
        bucket,
        object_key,
        ExtraArgs={
            "ContentType": content_type,
            "ContentDisposition": f"attachment; filename*=UTF-8''{quote(package.name)}",
        },
    )

    public_url = f"{base_url}/{quote(object_key, safe='/')}"
    print(f"R2 upload complete: {public_url}")
    github_output = os.environ.get("GITHUB_OUTPUT")
    if github_output:
        with open(github_output, "a", encoding="utf-8") as output:
            output.write(f"download_url={public_url}\n")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"R2 upload failed: {error}", file=sys.stderr)
        raise
