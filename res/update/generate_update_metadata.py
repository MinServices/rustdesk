#!/usr/bin/env python3
"""
Generate and sign RustDesk update metadata sidecar files (rustdesk-update.json and rustdesk-update.json.sig).
Uses Ed25519 signature algorithm compatible with sodiumoxide / libsodium.
"""

import argparse
import base64
import datetime
import hashlib
import json
import os
import sys
from cryptography.hazmat.primitives.asymmetric import ed25519

SIGNATURE_CONTEXT = b"RustDesk update metadata v1\n"

def get_or_create_key(key_path: str) -> ed25519.Ed25519PrivateKey:
    if os.path.exists(key_path):
        with open(key_path, "rb") as f:
            raw = f.read()
        return ed25519.Ed25519PrivateKey.from_private_bytes(raw)
    else:
        key = ed25519.Ed25519PrivateKey.generate()
        raw = key.private_bytes_raw()
        os.makedirs(os.path.dirname(os.path.abspath(key_path)), exist_ok=True)
        with open(key_path, "wb") as f:
            f.write(raw)
        print(f"Created new private key at: {key_path}")
        return key

def compute_sha256(file_path: str) -> str:
    h = hashlib.sha256()
    with open(file_path, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest().lower()

def main():
    parser = argparse.ArgumentParser(description="Generate and sign RustDesk update metadata")
    parser.add_argument("--version", required=True, help="Display version, e.g. 1.5.5")
    parser.add_argument("--release-id", required=True, help="GitHub release tag, e.g. 1.5.5")
    parser.add_argument("--owner", default="MinServices", help="GitHub repo owner, default: MinServices")
    parser.add_argument("--repo", default="rustdesk", help="GitHub repo name, default: rustdesk")
    parser.add_argument("--key", default="res/update/min9802_ed25519.key", help="Path to ed25519 private key")
    parser.add_argument("--key-id", default="min9802-ed25519-main", help="Signature key ID")
    parser.add_argument("--exe", required=True, help="Path to Windows x86_64 setup exe")
    parser.add_argument("--output-dir", default=".", help="Output directory for json and sig")
    args = parser.parse_args()

    if not os.path.exists(args.exe):
        print(f"Error: exe file not found: {args.exe}", file=sys.stderr)
        sys.exit(1)

    private_key = get_or_create_key(args.key)
    pub_key = private_key.public_key()
    pub_bytes = list(pub_key.public_bytes_raw())

    exe_basename = os.path.basename(args.exe)
    exe_size = os.path.getsize(args.exe)
    exe_sha256 = compute_sha256(args.exe)
    artifact_url = f"https://github.com/{args.owner}/{args.repo}/releases/download/{args.release_id}/{exe_basename}"

    now_iso = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    metadata = {
        "schema_version": 1,
        "app": "rustdesk",
        "package_id": "rustdesk",
        "version": args.version,
        "release_id": args.release_id,
        "published_at": now_iso,
        "signature_key_id": args.key_id,
        "artifacts": [
            {
                "platform": "windows",
                "arch": "x86_64",
                "format": "exe",
                "url": artifact_url,
                "file_name": exe_basename,
                "size": exe_size,
                "sha256": exe_sha256
            }
        ]
    }

    metadata_bytes = json.dumps(metadata, separators=(',', ':')).encode('utf-8')

    # Sign with context prefix
    signed_payload = SIGNATURE_CONTEXT + metadata_bytes
    sig = private_key.sign(signed_payload)
    sig_b64 = base64.b64encode(sig).decode('ascii')

    sig_data = {
        "schema_version": 1,
        "algorithm": "ed25519",
        "key_id": args.key_id,
        "signature": sig_b64
    }
    sig_bytes = json.dumps(sig_data, separators=(',', ':')).encode('utf-8')

    os.makedirs(args.output_dir, exist_ok=True)
    metadata_path = os.path.join(args.output_dir, "rustdesk-update.json")
    sig_path = os.path.join(args.output_dir, "rustdesk-update.json.sig")

    with open(metadata_path, "wb") as f:
        f.write(metadata_bytes)
    with open(sig_path, "wb") as f:
        f.write(sig_bytes)

    print("=== Update Metadata Generated Successfully ===")
    print(f"Metadata file:  {metadata_path} ({len(metadata_bytes)} bytes)")
    print(f"Signature file: {sig_path} ({len(sig_bytes)} bytes)")
    print(f"Artifact URL:   {artifact_url}")
    print(f"Artifact SHA:   {exe_sha256}")
    print(f"Key ID:         {args.key_id}")
    print(f"Public Key:     {pub_bytes}")

if __name__ == "__main__":
    main()
