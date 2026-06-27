#!/usr/bin/env python3
"""Build a Monster & Hunter hot-update manifest from a package plan."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

BUILD_ONLY_PACKAGE_KEYS = {
    "description",
    "export_command",
    "export_preset",
    "export_strategy",
    "exclude_filters",
    "file",
    "include_filters",
    "patches",
    "ship_as_manifest_package",
    "strategy",
}


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        value = json.load(handle)
    if not isinstance(value, dict):
        raise ValueError(f"{path} must contain a JSON object")
    return value


def normalize_package(plan_package: dict[str, Any], package_root: Path) -> dict[str, Any]:
    package_id = str(plan_package.get("id", "")).strip()
    if not package_id:
        raise ValueError("Each package needs an id")

    file_value = str(plan_package.get("file", "")).strip()
    if not file_value:
        raise ValueError(f"Package {package_id} needs a file")

    package_file = package_root / file_value
    if not package_file.is_file():
        raise FileNotFoundError(f"Package file not found: {package_file}")

    output = dict(plan_package)
    for key in BUILD_ONLY_PACKAGE_KEYS:
        output.pop(key, None)
    output.setdefault("type", "patch")
    output.setdefault("required", True)
    output.setdefault("restart_required", True)
    output.setdefault("load_order", 1000)
    output["url"] = str(Path(file_value).as_posix())
    output["size_bytes"] = package_file.stat().st_size
    output["sha256"] = sha256_file(package_file)
    return output


def build_manifest(plan: dict[str, Any], package_root: Path) -> dict[str, Any]:
    packages = plan.get("packages", [])
    if not isinstance(packages, list):
        raise ValueError("packages must be an array")

    manifest = {key: value for key, value in plan.items() if key != "packages"}
    manifest.setdefault("schema_version", 1)
    manifest.setdefault("protocol_version", 1)
    manifest["packages"] = [
        normalize_package(package, package_root)
        for package in packages
        if isinstance(package, dict)
    ]
    manifest["packages"].sort(key=lambda item: (int(item.get("load_order", 1000)), str(item.get("id", ""))))
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser(description="Build a hot-update manifest with size and SHA-256 metadata.")
    parser.add_argument("--plan", required=True, type=Path, help="Path to package_plan.json")
    parser.add_argument("--package-root", type=Path, default=None, help="Root containing package files")
    parser.add_argument("--out", required=True, type=Path, help="Output manifest path")
    args = parser.parse_args()

    plan_path = args.plan.resolve()
    package_root = args.package_root.resolve() if args.package_root else plan_path.parent.resolve()
    output_path = args.out.resolve()

    plan = load_json(plan_path)
    manifest = build_manifest(plan, package_root)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(manifest, handle, indent=2, sort_keys=True)
        handle.write("\n")

    print(f"Wrote {output_path}")
    print(f"Packages: {len(manifest['packages'])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
