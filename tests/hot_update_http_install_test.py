#!/usr/bin/env python3
"""End-to-end local HTTP install test for the Godot hot updater."""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import threading
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, format: str, *args: object) -> None:
        return


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


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


def run_godot(repo_root: Path, script_path: str, env: dict[str, str]) -> subprocess.CompletedProcess[str]:
    godot_bin = resolve_godot_bin(env)
    return subprocess.run(
        godot_command(godot_bin, script_path),
        cwd=repo_root,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=45,
        check=True,
    )


def main() -> int:
    repo_root = Path(__file__).resolve().parents[1]
    temp_root = Path(tempfile.mkdtemp(prefix="maomao-hot-update-http-"))
    server: ThreadingHTTPServer | None = None
    try:
        package_dir = temp_root / "packages"
        package_dir.mkdir(parents=True, exist_ok=True)
        package_path = package_dir / "core_patch_0.4.5.pck"

        env = os.environ.copy()
        env["MAOMAO_TEST_PCK_PATH"] = str(package_path)
        make_pack = run_godot(repo_root, "tests/hot_update_make_test_pack.gd", env)
        print(make_pack.stdout, end="")

        manifest = {
            "schema_version": 1,
            "app_id": "monster_hunter",
            "channel": "dev",
            "version": "0.4.5",
            "content_version": "2026.06.27.http-test",
            "min_app_version": "0.4.4",
            "protocol_version": 1,
            "packages": [
                {
                    "id": "core_patch",
                    "version": "0.4.5",
                    "type": "patch",
                    "url": "packages/core_patch_0.4.5.pck",
                    "sha256": sha256_file(package_path),
                    "size_bytes": package_path.stat().st_size,
                    "load_order": 10,
                    "required": True,
                    "restart_required": True,
                }
            ],
        }
        (temp_root / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")

        handler = lambda *args, **kwargs: QuietHandler(*args, directory=str(temp_root), **kwargs)
        server = ThreadingHTTPServer(("127.0.0.1", 0), handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        port = int(server.server_address[1])

        env["MAOMAO_TEST_MANIFEST_URL"] = f"http://127.0.0.1:{port}/manifest.json"
        install = run_godot(repo_root, "tests/hot_update_http_install_test.gd", env)
        print(install.stdout, end="")
        if "[HotUpdateHttpInstallTest] PASS" not in install.stdout:
            raise AssertionError("Godot HTTP install test did not report PASS")
    finally:
        if server is not None:
            server.shutdown()
            server.server_close()
        shutil.rmtree(temp_root, ignore_errors=True)
    print("[HotUpdateHttpInstallPythonTest] PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
