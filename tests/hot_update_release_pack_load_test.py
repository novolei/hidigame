#!/usr/bin/env python3
"""Verify that generated release PCK files can be mounted by Godot."""

from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path


def resolve_godot_bin(env: dict[str, str]) -> str:
    configured = env.get("GODOT_BIN", "").strip()
    if configured:
        return configured

    for executable_name in ("godot", "godot.cmd", "godot.exe"):
        resolved = shutil.which(executable_name, path=env.get("PATH"))
        if resolved:
            return resolved

    raise FileNotFoundError("Godot executable not found. Set GODOT_BIN to the Godot 4.7 binary path.")


def godot_command(godot_bin: str, script_path: str) -> list[str]:
    args = [godot_bin, "--headless", "--path", ".", "--script", script_path]
    if godot_bin.lower().endswith((".bat", ".cmd")):
        return ["cmd.exe", "/c"] + args
    return args


def main() -> int:
    repo_root = Path(__file__).resolve().parents[1]
    release_dir = Path(os.environ.get("MAOMAO_TEST_RELEASE_DIR", repo_root / "builds/hot_update/dev/0.4.5")).resolve()
    manifest_path = release_dir / "manifest.json"
    if not manifest_path.is_file():
        raise FileNotFoundError(f"Release manifest not found: {manifest_path}")

    env = os.environ.copy()
    env["MAOMAO_TEST_RELEASE_MANIFEST_PATH"] = str(manifest_path)
    godot_bin = resolve_godot_bin(env)
    result = subprocess.run(
        godot_command(godot_bin, "tests/hot_update_release_pack_load_test.gd"),
        cwd=repo_root,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=180,
        check=False,
    )
    print(result.stdout, end="")
    if result.returncode != 0:
        raise subprocess.CalledProcessError(result.returncode, result.args, output=result.stdout)
    print("[HotUpdateReleasePackLoadPythonTest] PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
