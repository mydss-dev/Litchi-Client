"""Upload a self-hosted Litchi release directory to Cloudflare R2."""

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


def main() -> None:
    files = [Path(value) for value in sys.argv[1:]]
    if not files:
        raise RuntimeError("Provide update.json and at least one package file")
    if any(not path.is_file() for path in files):
        raise RuntimeError("Every upload argument must be a file")
    if "update.json" not in {path.name for path in files} or len(files) < 2:
        raise RuntimeError("Upload must contain update.json and at least one package")

    account_id = required_env("R2_ACCOUNT_ID")
    access_key = required_env("R2_ACCESS_KEY_ID")
    secret_key = required_env("R2_SECRET_ACCESS_KEY")
    bucket = required_env("R2_BUCKET")
    base_url = required_env("DOWNLOAD_BASE_URL").rstrip("/")
    prefix = os.environ.get("R2_PREFIX", "").strip().strip("/")

    client = boto3.client(
        "s3",
        endpoint_url=f"https://{account_id}.r2.cloudflarestorage.com",
        aws_access_key_id=access_key,
        aws_secret_access_key=secret_key,
        region_name="auto",
        config=Config(signature_version="s3v4"),
    )

    for path in files:
        object_key = f"{prefix}/{path.name}" if prefix else path.name
        content_type = mimetypes.guess_type(path.name)[0] or "application/octet-stream"
        extra = {"ContentType": content_type}
        if path.suffix.lower() not in {".json", ".txt"}:
            extra["ContentDisposition"] = (
                f"attachment; filename*=UTF-8''{quote(path.name)}"
            )
        client.upload_file(str(path), bucket, object_key, ExtraArgs=extra)
        print(f"Uploaded {path.name}: {base_url}/{quote(path.name)}")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"R2 upload failed: {error}", file=sys.stderr)
        raise
