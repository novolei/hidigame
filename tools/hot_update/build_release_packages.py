#!/usr/bin/env python3
"""Create Godot hot-update package release plans, packages, and manifests."""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from build_manifest import build_manifest, load_json


@dataclass(frozen=True)
class ReleaseOptions:
    project_root: Path
    partitions_path: Path
    release_dir: Path
    version: str
    content_version: str
    min_app_version: str
    base_url: str
    mirror_base_urls: tuple[dict[str, str], ...]
    channel: str
    protocol_version: int
    godot_bin: str
    template_preset: str
    patches: str


def godot_string(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


def load_partitions(path: Path) -> dict[str, Any]:
    data = load_json(path)
    partitions = data.get("partitions", [])
    if not isinstance(partitions, list):
        raise ValueError("partitions must be an array")
    return data


def package_file(partition_id: str, version: str) -> str:
    return f"packages/{partition_id}_{version}.pck"


def package_type_for(partition: dict[str, Any]) -> str:
    explicit = str(partition.get("type", "")).strip()
    if explicit:
        return explicit
    return "patch" if str(partition.get("strategy", "")) == "godot_export_patch" else "content"


def manifest_package(partition: dict[str, Any], version: str) -> dict[str, Any]:
    partition_id = str(partition.get("id", "")).strip()
    if not partition_id:
        raise ValueError("Every partition needs an id")
    return {
        "file": package_file(partition_id, version),
        "id": partition_id,
        "load_order": int(partition.get("load_order", 1000)),
        "required": bool(partition.get("required", True)),
        "restart_required": bool(partition.get("restart_required", True)),
        "type": package_type_for(partition),
        "version": str(partition.get("version", version)),
    }


def export_package(partition: dict[str, Any], release_dir: Path, version: str) -> dict[str, Any]:
    partition_id = str(partition.get("id", "")).strip()
    output_path = release_dir / package_file(partition_id, version)
    include_filters = partition.get("include_filters", [])
    exclude_filters = partition.get("exclude_filters", [])
    if not isinstance(include_filters, list) or not isinstance(exclude_filters, list):
        raise ValueError(f"Partition {partition_id} filters must be arrays")
    return {
        "id": partition_id,
        "description": str(partition.get("description", "")),
        "load_order": int(partition.get("load_order", 1000)),
        "strategy": str(partition.get("strategy", "godot_export_pack")),
        "preset": f"HotUpdate_{partition_id}",
        "output": output_path.as_posix(),
        "include_filters": [str(value) for value in include_filters],
        "exclude_filters": [str(value) for value in exclude_filters],
    }


def build_release_plan(partitions: dict[str, Any], options: ReleaseOptions) -> tuple[dict[str, Any], dict[str, Any]]:
    package_plan: dict[str, Any] = {
        "app_id": str(partitions.get("app_id", "monster_hunter")),
        "base_url": options.base_url,
        "channel": options.channel,
        "content_version": options.content_version,
        "min_app_version": options.min_app_version,
        "packages": [],
        "protocol_version": options.protocol_version,
        "schema_version": int(partitions.get("schema_version", 1)),
        "version": options.version,
    }
    if options.mirror_base_urls:
        package_plan["mirrors"] = [dict(mirror) for mirror in options.mirror_base_urls]
    export_plan: dict[str, Any] = {
        "schema_version": int(partitions.get("schema_version", 1)),
        "project_root": options.project_root.as_posix(),
        "release_dir": options.release_dir.as_posix(),
        "template_preset": options.template_preset,
        "godot_bin": options.godot_bin,
        "packages": [],
    }
    for value in partitions.get("partitions", []):
        if not isinstance(value, dict):
            continue
        if not bool(value.get("ship_as_manifest_package", False)):
            continue
        package_plan["packages"].append(manifest_package(value, options.version))
        export_plan["packages"].append(export_package(value, options.release_dir, options.version))
    package_plan["packages"].sort(key=lambda item: (int(item.get("load_order", 1000)), str(item.get("id", ""))))
    export_plan["packages"].sort(key=lambda item: (int(item.get("load_order", 1000)), str(item.get("id", ""))))
    return package_plan, export_plan


def write_json(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(data, handle, indent=2, sort_keys=True)
        handle.write("\n")


def section_map(text: str) -> dict[str, str]:
    matches = list(re.finditer(r"(?m)^\[([^\]]+)\]\s*$", text))
    result: dict[str, str] = {}
    for index, match in enumerate(matches):
        end = matches[index + 1].start() if index + 1 < len(matches) else len(text)
        result[match.group(1)] = text[match.start():end].strip() + "\n"
    return result


def find_template_preset(text: str, preset_name: str) -> tuple[str, str]:
    sections = section_map(text)
    for name, body in sections.items():
        if not re.fullmatch(r"preset\.\d+", name):
            continue
        if re.search(rf'(?m)^name={re.escape(godot_string(preset_name))}\s*$', body):
            preset_index = name.split(".", 1)[1]
            options = sections.get(f"preset.{preset_index}.options", "")
            if not options:
                raise ValueError(f"Preset {preset_name} has no options section")
            return body, options
    raise ValueError(f"Could not find export preset named {preset_name}")


def set_key(block: str, key: str, value: str) -> str:
    pattern = rf"(?m)^{re.escape(key)}=.*$"
    line = f"{key}={value}"
    if re.search(pattern, block):
        return re.sub(pattern, line, block)
    return block.rstrip() + f"\n{line}\n"


def rewrite_section_header(block: str, header: str) -> str:
    return re.sub(r"(?m)^\[[^\]]+\]\s*$", header, block, count=1)


def render_temp_export_presets(original_text: str, template_preset: str, package: dict[str, Any]) -> str:
    preset_block, options_block = find_template_preset(original_text, template_preset)
    preset_block = rewrite_section_header(preset_block, "[preset.0]")
    preset_block = set_key(preset_block, "name", godot_string(str(package["preset"])))
    preset_block = set_key(preset_block, "export_filter", godot_string("resources"))
    preset_block = set_key(preset_block, "export_files", "PackedStringArray()")
    preset_block = set_key(preset_block, "include_filter", godot_string(",".join(package["include_filters"])))
    preset_block = set_key(preset_block, "exclude_filter", godot_string(",".join(package["exclude_filters"])))
    preset_block = set_key(preset_block, "export_path", godot_string(str(package["output"])))
    options_block = rewrite_section_header(options_block, "[preset.0.options]")
    options_block = set_key(options_block, "binary_format/embed_pck", "false")
    return "\n".join([
        "[runnable_presets]\n",
        f"{godot_string(str(package['preset']))}={godot_string(str(package['preset']))}\n",
        preset_block.strip() + "\n",
        options_block.strip() + "\n",
    ])


def export_command(options: ReleaseOptions, package: dict[str, Any]) -> list[str]:
    action = "--export-patch" if package.get("strategy") == "godot_export_patch" and options.patches else "--export-pack"
    command = [
        options.godot_bin,
        "--headless",
        "--path",
        str(options.project_root),
    ]
    if action == "--export-patch":
        command.extend(["--patches", options.patches])
    command.extend([action, str(package["preset"]), str(Path(str(package["output"])))])
    return command


def resolve_godot_bin(configured: str) -> str:
    value = configured.strip() or os.environ.get("GODOT_BIN", "").strip() or "godot"
    candidate = Path(value)
    if candidate.is_file():
        return str(candidate)
    resolved = shutil.which(value)
    if resolved:
        return resolved
    for executable_name in ("godot", "godot.cmd", "godot.exe"):
        resolved = shutil.which(executable_name)
        if resolved:
            return resolved
    raise FileNotFoundError("Godot executable not found. Pass --godot-bin or set GODOT_BIN.")


def godot_process_command(command: list[str]) -> list[str]:
    if command and command[0].lower().endswith((".bat", ".cmd")):
        return ["cmd.exe", "/c"] + command
    return command


def run_exports(options: ReleaseOptions, export_plan: dict[str, Any]) -> None:
    export_presets_path = options.project_root / "export_presets.cfg"
    original_text = export_presets_path.read_text(encoding="utf-8")
    backup_path = export_presets_path.with_suffix(".cfg.hot_update_backup")
    shutil.copy2(export_presets_path, backup_path)
    resolved_godot_bin = resolve_godot_bin(options.godot_bin)
    try:
        for package in export_plan["packages"]:
            output_path = Path(str(package["output"]))
            output_path.parent.mkdir(parents=True, exist_ok=True)
            export_presets_path.write_text(
                render_temp_export_presets(original_text, options.template_preset, package),
                encoding="utf-8",
                newline="\n",
            )
            command = export_command(options, package)
            command[0] = resolved_godot_bin
            print("Running:", " ".join(command))
            subprocess.run(godot_process_command(command), cwd=options.project_root, check=True)
    finally:
        shutil.copy2(backup_path, export_presets_path)
        backup_path.unlink(missing_ok=True)


def write_export_commands(path: Path, options: ReleaseOptions) -> None:
    command = [
        "python",
        "tools/hot_update/build_release_packages.py",
        "--partitions",
        options.partitions_path.as_posix(),
        "--release-dir",
        options.release_dir.as_posix(),
        "--version",
        options.version,
        "--content-version",
        options.content_version,
        "--min-app-version",
        options.min_app_version,
        "--base-url",
        options.base_url,
    ]
    for mirror in options.mirror_base_urls:
        command.extend(["--mirror-base-url", f"{mirror['id']}={mirror['base_url']}"])
    command.extend([
        "--channel",
        options.channel,
        "--protocol-version",
        str(options.protocol_version),
        "--godot-bin",
        options.godot_bin,
        "--template-preset",
        options.template_preset,
        "--run-export",
    ])
    if options.patches:
        command.extend(["--patches", options.patches])
    quoted = " ".join("'" + part.replace("'", "''") + "'" for part in command)
    path.write_text(
        "$ErrorActionPreference = \"Stop\"\n"
        f"Set-Location -LiteralPath '{options.project_root.as_posix()}'\n"
        f"& {quoted}\n",
        encoding="utf-8",
        newline="\n",
    )


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build a hot-update package release plan and optionally export packages.")
    parser.add_argument("--partitions", type=Path, default=Path("tools/hot_update/content_partitions.example.json"))
    parser.add_argument("--release-dir", required=True, type=Path)
    parser.add_argument("--version", required=True)
    parser.add_argument("--content-version", required=True)
    parser.add_argument("--min-app-version", required=True)
    parser.add_argument("--base-url", required=True)
    parser.add_argument(
        "--mirror-base-url",
        action="append",
        default=[],
        help="Auxiliary package base URL, optionally ID=URL. Repeatable or comma-separated.",
    )
    parser.add_argument("--channel", default="dev")
    parser.add_argument("--protocol-version", type=int, default=1)
    parser.add_argument("--godot-bin", default=os.environ.get("GODOT_BIN", "godot"))
    parser.add_argument("--template-preset", default="Windows Desktop")
    parser.add_argument("--patches", default="", help="Comma-separated previous pack paths for Godot --export-patch.")
    parser.add_argument("--run-export", action="store_true", help="Run Godot exports after writing the plans.")
    parser.add_argument("--skip-manifest", action="store_true", help="Do not generate manifest.json after exports.")
    return parser.parse_args(argv)


def parse_mirror_base_urls(values: list[str]) -> tuple[dict[str, str], ...]:
    result: list[dict[str, str]] = []
    next_index = 1
    for raw_value in values:
        for item_value in str(raw_value).split(","):
            item = item_value.strip()
            if not item:
                continue
            if "=" in item:
                mirror_id, url = item.split("=", 1)
                mirror_id = mirror_id.strip() or f"mirror_{next_index}"
            else:
                mirror_id = f"mirror_{next_index}"
                url = item
            clean_url = url.strip().rstrip("/")
            if not clean_url:
                continue
            result.append({"id": mirror_id, "base_url": clean_url})
            next_index += 1
    return tuple(result)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    project_root = Path.cwd().resolve()
    partitions_path = (project_root / args.partitions).resolve() if not args.partitions.is_absolute() else args.partitions.resolve()
    release_dir = (project_root / args.release_dir).resolve() if not args.release_dir.is_absolute() else args.release_dir.resolve()
    options = ReleaseOptions(
        project_root=project_root,
        partitions_path=partitions_path,
        release_dir=release_dir,
        version=args.version,
        content_version=args.content_version,
        min_app_version=args.min_app_version,
        base_url=args.base_url.rstrip("/"),
        mirror_base_urls=parse_mirror_base_urls(args.mirror_base_url),
        channel=args.channel,
        protocol_version=args.protocol_version,
        godot_bin=args.godot_bin,
        template_preset=args.template_preset,
        patches=args.patches,
    )

    partitions = load_partitions(options.partitions_path)
    package_plan, export_plan = build_release_plan(partitions, options)
    package_plan_path = options.release_dir / "package_plan.json"
    export_plan_path = options.release_dir / "export_plan.json"
    commands_path = options.release_dir / "export_hot_update.ps1"
    write_json(package_plan_path, package_plan)
    write_json(export_plan_path, export_plan)
    write_export_commands(commands_path, options)
    print(f"Wrote {package_plan_path}")
    print(f"Wrote {export_plan_path}")
    print(f"Wrote {commands_path}")

    if args.run_export:
        run_exports(options, export_plan)
        if not args.skip_manifest:
            manifest = build_manifest(package_plan, options.release_dir)
            manifest_path = options.release_dir / "manifest.json"
            write_json(manifest_path, manifest)
            print(f"Wrote {manifest_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
