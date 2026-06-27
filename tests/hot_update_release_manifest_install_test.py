#!/usr/bin/env python3
"""Install-test a real generated hot-update release over local HTTP."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import tempfile
import threading
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, format: str, *args: object) -> None:
        return


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


def run_godot(repo_root: Path, script_path: str, env: dict[str, str], timeout_sec: int) -> subprocess.CompletedProcess[str]:
    godot_bin = resolve_godot_bin(env)
    result = subprocess.run(
        godot_command(godot_bin, script_path),
        cwd=repo_root,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=timeout_sec,
    )
    if result.returncode != 0:
        print(result.stdout, end="")
        raise subprocess.CalledProcessError(result.returncode, result.args, output=result.stdout)
    return result


def main() -> int:
    repo_root = Path(__file__).resolve().parents[1]
    release_dir = Path(os.environ.get("MAOMAO_TEST_RELEASE_DIR", repo_root / "builds/hot_update/dev/0.4.5")).resolve()
    manifest_path = release_dir / "manifest.json"
    if not manifest_path.is_file():
        raise FileNotFoundError(f"Release manifest not found: {manifest_path}")

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    all_packages = list(manifest.get("packages", []))
    selected_ids = selected_package_ids()
    packages = all_packages if selected_ids == ["all"] else [
        package for package in all_packages
        if str(package.get("id", "")) in selected_ids
    ]
    package_ids = [str(package["id"]) for package in packages]
    if not package_ids:
        raise AssertionError(f"Release manifest has no selected packages: {selected_ids}")
    for package in packages:
        package_path = release_dir / str(package["url"])
        if not package_path.is_file():
            raise FileNotFoundError(f"Release package not found: {package_path}")

    server: ThreadingHTTPServer | None = None
    local_manifest_path = release_dir / "manifest.local-http-test.json"
    try:
        handler = lambda *args, **kwargs: QuietHandler(*args, directory=str(release_dir), **kwargs)
        server = ThreadingHTTPServer(("127.0.0.1", 0), handler)
        port = int(server.server_address[1])
        local_manifest = dict(manifest)
        if os.environ.get("MAOMAO_TEST_FORCE_PACKAGE_PRIMARY_404", "").strip() in {"1", "true", "yes", "on"}:
            local_manifest["base_url"] = f"http://127.0.0.1:{port}/missing-primary"
            local_manifest["mirrors"] = [{"id": "AL", "base_url": f"http://127.0.0.1:{port}"}]
        else:
            local_manifest["base_url"] = f"http://127.0.0.1:{port}"
        local_manifest["packages"] = packages
        local_manifest_path.write_text(json.dumps(local_manifest, indent=2), encoding="utf-8")

        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()

        env = os.environ.copy()
        env["MAOMAO_TEST_MANIFEST_URL"] = f"http://127.0.0.1:{port}/{local_manifest_path.name}"
        env["MAOMAO_TEST_EXPECTED_PACKAGE_IDS"] = ",".join(package_ids)
        env["MAOMAO_TEST_MARKER_PATH"] = ""
        if selected_ids == ["all"] or any(not bool(package.get("required", True)) for package in packages):
            env["MAOMAO_TEST_INCLUDE_OPTIONAL_PACKAGES"] = "1"
        env["MAOMAO_TEST_MANIFEST_TIMEOUT_SEC"] = "15"
        install_timeout_sec = int(os.environ.get("MAOMAO_TEST_INSTALL_TIMEOUT_SEC", "360"))
        env["MAOMAO_TEST_INSTALL_TIMEOUT_SEC"] = str(install_timeout_sec)
        install = run_godot(repo_root, "tests/hot_update_http_install_test.gd", env, install_timeout_sec + 90)
        print(install.stdout, end="")
        if "[HotUpdateHttpInstallTest] PASS" not in install.stdout:
            raise AssertionError("Godot release manifest install test did not report PASS")
    finally:
        if server is not None:
            server.shutdown()
            server.server_close()
        local_manifest_path.unlink(missing_ok=True)

    print("[HotUpdateReleaseManifestInstallTest] PASS")
    return 0


def selected_package_ids() -> list[str]:
    raw = os.environ.get("MAOMAO_TEST_RELEASE_PACKAGE_IDS", "core_patch").strip()
    if raw.lower() == "all":
        return ["all"]
    result = [value.strip() for value in raw.split(",") if value.strip()]
    return result or ["core_patch"]


if __name__ == "__main__":
    raise SystemExit(main())
