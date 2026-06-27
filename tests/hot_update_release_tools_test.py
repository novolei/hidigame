#!/usr/bin/env python3
"""Smoke tests for hot-update release tooling."""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


def main() -> int:
    repo_root = Path(__file__).resolve().parents[1]
    sys.path.insert(0, str(repo_root / "tools" / "hot_update"))
    import build_release_packages as release_tool

    release_dir = Path(tempfile.mkdtemp(prefix="maomao-hot-update-release-"))
    try:
        wrapped_command = release_tool.godot_process_command(["C:/Godot/godot.cmd", "--version"])
        if wrapped_command != ["cmd.exe", "/c", "C:/Godot/godot.cmd", "--version"]:
            raise AssertionError(f"Windows Godot .cmd wrapper changed unexpectedly: {wrapped_command}")
        native_command = release_tool.godot_process_command(["godot.exe", "--version"])
        if native_command != ["godot.exe", "--version"]:
            raise AssertionError(f"Native Godot command should not be wrapped: {native_command}")

        command = [
            sys.executable,
            "tools/hot_update/build_release_packages.py",
            "--partitions",
            "tools/hot_update/content_partitions.example.json",
            "--release-dir",
            str(release_dir),
            "--version",
            "0.4.5",
            "--content-version",
            "2026.06.27.1",
            "--min-app-version",
            "0.4.4",
            "--base-url",
            "https://updates.example.com/maomao/dev",
        ]
        subprocess.run(command, cwd=repo_root, check=True)

        package_plan = json.loads((release_dir / "package_plan.json").read_text(encoding="utf-8"))
        export_plan = json.loads((release_dir / "export_plan.json").read_text(encoding="utf-8"))
        package_ids = [package["id"] for package in package_plan["packages"]]
        if package_ids != ["core_patch", "characters_party_monster", "maps_warehouse", "audio_video"]:
            raise AssertionError(f"Unexpected package ids/order: {package_ids}")
        if any("include_filters" in package for package in package_plan["packages"]):
            raise AssertionError("Build-only include filters leaked into package_plan packages")
        if len(export_plan["packages"]) != len(package_plan["packages"]):
            raise AssertionError("Export plan and package plan package counts differ")
        if not (release_dir / "export_hot_update.ps1").is_file():
            raise AssertionError("PowerShell export command file was not written")
        rendered_preset = release_tool.render_temp_export_presets(
            (repo_root / "export_presets.cfg").read_text(encoding="utf-8"),
            "Windows Desktop",
            export_plan["packages"][0],
        )
        if "export_files=PackedStringArray()" not in rendered_preset:
            raise AssertionError("Generated export preset should include an explicit export_files key")

        for package in package_plan["packages"]:
            package_path = release_dir / package["file"]
            package_path.parent.mkdir(parents=True, exist_ok=True)
            package_path.write_text(f"dummy package {package['id']}", encoding="utf-8")

        subprocess.run(
            [
                sys.executable,
                "tools/hot_update/build_manifest.py",
                "--plan",
                str(release_dir / "package_plan.json"),
                "--package-root",
                str(release_dir),
                "--out",
                str(release_dir / "manifest.json"),
            ],
            cwd=repo_root,
            check=True,
        )
        manifest = json.loads((release_dir / "manifest.json").read_text(encoding="utf-8"))
        for package in manifest["packages"]:
            if "file" in package or "include_filters" in package or "exclude_filters" in package:
                raise AssertionError(f"Build-only keys leaked into manifest package: {package}")
            if len(package.get("sha256", "")) != 64 or int(package.get("size_bytes", 0)) <= 0:
                raise AssertionError(f"Manifest package lacks size/SHA metadata: {package}")
    finally:
        shutil.rmtree(release_dir, ignore_errors=True)
    print("[HotUpdateReleaseToolsTest] PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
