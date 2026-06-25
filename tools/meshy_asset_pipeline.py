#!/usr/bin/env python3
"""Small Meshy API helper for this Godot project.

The script reads MESHY_API_KEY from the environment. It never stores or prints
the key. Generated files are downloaded under meshy_output/ for review before
they are imported into Godot assets or scenes.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Any

import requests


BASE_URL = "https://api.meshy.ai"
OUTPUT_ROOT = Path.cwd() / "meshy_output"
HISTORY_FILE = OUTPUT_ROOT / "history.json"


class MeshyError(RuntimeError):
    pass


def get_api_key() -> str:
    api_key = os.environ.get("MESHY_API_KEY", "").strip()
    if api_key or os.name != "nt":
        return api_key

    try:
        import winreg

        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as key:
            value, _value_type = winreg.QueryValueEx(key, "MESHY_API_KEY")
            return str(value).strip()
    except OSError:
        return ""


def get_session() -> requests.Session:
    api_key = get_api_key()
    if not api_key:
        raise MeshyError("MESHY_API_KEY is not set.")

    session = requests.Session()
    session.headers.update({"Authorization": f"Bearer {api_key}"})
    return session


def request_json(session: requests.Session, method: str, path: str, **kwargs: Any) -> dict[str, Any]:
    response = session.request(method, f"{BASE_URL}{path}", timeout=kwargs.pop("timeout", 30), **kwargs)
    if response.status_code == 401:
        raise MeshyError("Meshy rejected the API key with HTTP 401.")
    if response.status_code == 402:
        raise MeshyError("Meshy reported insufficient credits with HTTP 402.")
    if response.status_code == 429:
        raise MeshyError("Meshy rate limited the request with HTTP 429.")
    response.raise_for_status()
    return response.json()


def get_balance(session: requests.Session) -> dict[str, Any]:
    return request_json(session, "GET", "/openapi/v1/balance")


def create_task(session: requests.Session, payload: dict[str, Any]) -> str:
    data = request_json(session, "POST", "/openapi/v2/text-to-3d", json=payload)
    task_id = data.get("result")
    if not isinstance(task_id, str) or not task_id:
        raise MeshyError(f"Unexpected create-task response: {data}")
    print(f"TASK_CREATED {task_id}", flush=True)
    return task_id


def poll_text_to_3d(session: requests.Session, task_id: str, timeout_seconds: int = 600) -> dict[str, Any]:
    start = time.monotonic()
    delay = 5
    poll_count = 0
    while time.monotonic() - start < timeout_seconds:
        poll_count += 1
        task = request_json(session, "GET", f"/openapi/v2/text-to-3d/{task_id}")
        status = str(task.get("status", "UNKNOWN"))
        progress = int(task.get("progress", 0) or 0)
        elapsed = int(time.monotonic() - start)
        print(f"TASK_STATUS {task_id} {status} {progress}% elapsed={elapsed}s poll={poll_count}", flush=True)
        if status == "SUCCEEDED":
            return task
        if status in {"FAILED", "CANCELED"}:
            error = task.get("task_error") or {}
            message = error.get("message") if isinstance(error, dict) else str(error)
            raise MeshyError(f"Task {task_id} ended with {status}: {message}")
        time.sleep(15 if progress >= 95 else delay)
        if progress < 95:
            delay = min(int(delay * 1.5), 30)
    raise MeshyError(f"Timed out waiting for Meshy task {task_id}.")


def slugify(value: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")
    return slug[:42] or "meshy-asset"


def make_project_dir(prompt: str, task_id: str) -> Path:
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    project_dir = OUTPUT_ROOT / f"{timestamp}_{slugify(prompt)}_{task_id[:8]}"
    project_dir.mkdir(parents=True, exist_ok=True)
    return project_dir


def download_file(session: requests.Session, url: str, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with session.get(url, stream=True, timeout=300) as response:
        response.raise_for_status()
        with path.open("wb") as file:
            for chunk in response.iter_content(chunk_size=1024 * 256):
                if chunk:
                    file.write(chunk)
    print(f"DOWNLOADED {path} size={path.stat().st_size}", flush=True)


def write_metadata(project_dir: Path, metadata: dict[str, Any]) -> None:
    metadata_path = project_dir / "metadata.json"
    metadata_path.write_text(json.dumps(metadata, indent=2, ensure_ascii=False), encoding="utf-8")

    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    if HISTORY_FILE.exists():
        history = json.loads(HISTORY_FILE.read_text(encoding="utf-8"))
    else:
        history = {"version": 1, "projects": []}
    history["projects"].append(
        {
            "folder": project_dir.name,
            "prompt": metadata.get("prompt", ""),
            "created_at": metadata.get("created_at", ""),
            "tasks": metadata.get("tasks", []),
        }
    )
    HISTORY_FILE.write_text(json.dumps(history, indent=2, ensure_ascii=False), encoding="utf-8")


def model_urls(task: dict[str, Any]) -> dict[str, str]:
    urls = task.get("model_urls") or {}
    if not isinstance(urls, dict):
        return {}
    return {str(key): str(value) for key, value in urls.items() if value}


def run_text_to_3d(args: argparse.Namespace) -> None:
    if not args.confirm_spend:
        raise MeshyError("Refusing to spend credits. Re-run with --confirm-spend after reviewing the prompt.")

    session = get_session()
    balance_before = get_balance(session)
    print(f"BALANCE_BEFORE {json.dumps(balance_before, ensure_ascii=False)}", flush=True)

    preview_payload: dict[str, Any] = {
        "mode": "preview",
        "prompt": args.prompt,
        "ai_model": args.ai_model,
        "should_remesh": args.should_remesh,
        "topology": args.topology,
        "target_polycount": args.target_polycount,
        "symmetry_mode": args.symmetry_mode,
    }
    if args.model_type:
        preview_payload["model_type"] = args.model_type
    if args.pose_mode:
        preview_payload["pose_mode"] = args.pose_mode

    preview_id = create_task(session, preview_payload)
    preview_task = poll_text_to_3d(session, preview_id, args.timeout_seconds)
    project_dir = make_project_dir(args.prompt, preview_id)
    urls = model_urls(preview_task)
    if args.format not in urls:
        raise MeshyError(f"Preview task did not provide {args.format}. Available: {sorted(urls)}")
    download_file(session, urls[args.format], project_dir / f"preview.{args.format}")

    tasks = [{"stage": "preview", "task_id": preview_id, "available_formats": sorted(urls)}]
    if args.refine:
        refine_payload: dict[str, Any] = {
            "mode": "refine",
            "preview_task_id": preview_id,
            "ai_model": args.ai_model,
            "enable_pbr": args.enable_pbr,
        }
        if args.texture_prompt:
            refine_payload["texture_prompt"] = args.texture_prompt
        refine_id = create_task(session, refine_payload)
        refine_task = poll_text_to_3d(session, refine_id, args.timeout_seconds)
        refine_urls = model_urls(refine_task)
        if args.format not in refine_urls:
            raise MeshyError(f"Refine task did not provide {args.format}. Available: {sorted(refine_urls)}")
        download_file(session, refine_urls[args.format], project_dir / f"refined.{args.format}")
        tasks.append({"stage": "refine", "task_id": refine_id, "available_formats": sorted(refine_urls)})

    metadata = {
        "prompt": args.prompt,
        "created_at": datetime.now().isoformat(),
        "output_format": args.format,
        "tasks": tasks,
    }
    write_metadata(project_dir, metadata)

    balance_after = get_balance(session)
    print(f"PROJECT_DIR {project_dir}", flush=True)
    print(f"BALANCE_AFTER {json.dumps(balance_after, ensure_ascii=False)}", flush=True)


def main() -> int:
    parser = argparse.ArgumentParser(description="Meshy asset pipeline for the Godot project.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    subparsers.add_parser("balance", help="Check Meshy API balance without spending credits.")

    text_parser = subparsers.add_parser("text-to-3d", help="Generate a Meshy text-to-3d asset.")
    text_parser.add_argument("--prompt", required=True)
    text_parser.add_argument("--confirm-spend", action="store_true")
    text_parser.add_argument("--refine", action="store_true", help="Run refine after preview.")
    text_parser.add_argument("--format", default="glb", choices=["glb", "fbx", "obj", "usdz"])
    text_parser.add_argument("--ai-model", default="latest")
    text_parser.add_argument("--model-type", default="")
    text_parser.add_argument("--topology", default="triangle", choices=["triangle", "quad"])
    text_parser.add_argument("--target-polycount", type=int, default=30000)
    text_parser.add_argument("--symmetry-mode", default="auto", choices=["auto", "on", "off"])
    text_parser.add_argument("--pose-mode", default="", choices=["", "a-pose", "t-pose"])
    text_parser.add_argument("--should-remesh", action="store_true")
    text_parser.add_argument("--enable-pbr", action="store_true")
    text_parser.add_argument("--texture-prompt", default="")
    text_parser.add_argument("--timeout-seconds", type=int, default=600)

    args = parser.parse_args()
    try:
        if args.command == "balance":
            session = get_session()
            print(json.dumps(get_balance(session), indent=2, ensure_ascii=False))
        elif args.command == "text-to-3d":
            run_text_to_3d(args)
        else:
            raise MeshyError(f"Unknown command: {args.command}")
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
