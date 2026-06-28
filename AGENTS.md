<!-- fennara-agents-start -->
# Fennara MCP Guidelines

This project uses Fennara MCP for Godot-aware inspection, editing, runtime error capture, diagnostics, scene validation, screenshots, and project settings.

When working on Godot-specific files or behavior, always read `.fennara/ai/guidelines.md` first. This includes work involving `.tscn`, `.tres`, `.res`, `.gd`, `.cs`, `.gdshader`, `project.godot`, scenes, nodes, resources, shaders, project settings, gameplay, UI, animation, rendering, Fennara addon behavior, or Fennara MCP behavior.

The Fennara guidelines file explains which MCP tools to use, when to inspect before editing, how validation works, and which tool calls are mandatory before considering Godot work complete.
<!-- fennara-agents-end -->

# Project memory (keep in sync with CLAUDE.md)

This is **"Monster & Hunter"** (24-player 3D prop-hunt) built on the godot-3d-multiplayer-template;
Godot 4.7, GDScript only. Full guidance lives in `CLAUDE.md`. Key operational memory:

## Releases, hot updates, dedicated-server upgrade
Runbook: **[docs/RELEASE_AND_HOTUPDATE_OPERATIONS.md](docs/RELEASE_AND_HOTUPDATE_OPERATIONS.md)**.
- One-click: `tools/release_hotpatch.sh` (incremental client core_patch → TX update channel) and
  `tools/release_server.sh` (server export + **incremental** deploy). Need `GODOT_BIN` + TX SSH key.
- **Incremental dedicated-server deploy** uses `tools/deploy_server_pack_incremental.sh` (zstd
  `--patch-from`): uploads a few-MB patch and reconstructs the ~1.8 GB pack on the VPS (SHA-gated,
  full-upload fallback). Needs `zstd` locally (`winget install Meta.Zstandard`) and on the VPS.
- **Bootstrap gotcha:** never set `hot_update/load_installed_packs_on_boot` in `project.godot`
  (smart default: true in exports, false in editor). Hard-setting it `false` broke update apply
  in the 0.4.4 baseline and forced 0.4.5 to ship as a fresh full baseline. `project.godot` and
  `scripts/hot_update/**` are bootstrap and cannot be hot-updated.
- **Read a live server's version:** `ssh ubuntu@1.13.175.170 "journalctl -u maomao-public.service | grep DEDICATED-SERVER-VERSION | tail -1"`.
- `build_info.json` (repo root) is the build source of truth (version / build_id /
  content_version `<ver>+<YYYYMMDD>.<commit>` / role baseline|hotpatch); ships inside core_patch + server pack.
- TX (primary VPS): `ubuntu@1.13.175.170`, web root `/var/www/maomao-updates/maomao/dev/`,
  server pack `/opt/maomao/maomao_server.pck`, service `maomao-public.service`, Noray `8890/TCP`.
  AL (8.153.148.157) is **decommissioned** — do not deploy there.

## Code organization
Binding constraint: **[docs/CODE_ORGANIZATION_STANDARDS.md](docs/CODE_ORGANIZATION_STANDARDS.md)** —
group new code under `scripts/<feature>/`, one concept per file (>~600 lines = full), signals-up/
calls-down, and do not grow the oversized facades (`player.gd`, `level.gd`, `network.gd`, `main_menu_ui.gd`).
