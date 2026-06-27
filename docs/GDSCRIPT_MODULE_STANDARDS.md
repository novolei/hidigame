# GDScript Module Standards

Updated: 2026-06-27

These standards apply to new gameplay, networking, updater, UI, tooling, and test scripts in this project.

## File And Folder Layout

- Group new systems by feature under `scripts/<feature>/`.
- Keep runtime code out of `tools/`. Tools are editor/build/ops helpers only.
- Keep test entrypoints under `tests/`.
- Do not add one-off builder scripts into runtime folders.
- Avoid adding new code to `scripts/player.gd` or `scripts/network.gd` unless the change truly belongs to their current ownership boundary.

## Class Shape

- Use `class_name` for reusable runtime modules.
- Prefer `RefCounted` for pure data/validation helpers.
- Prefer `Node` only when signals, timers, HTTPRequest, scene tree access, or lifecycle callbacks are required.
- Keep autoloads thin. Autoloads orchestrate modules; they should not contain all implementation details.
- One file should own one concept.

## Typing

- Use explicit parameter and return types.
- Use explicit local variable types when values are not obvious.
- Avoid Variant-heavy APIs across module boundaries.
- If a function intentionally accepts loose manifest or JSON data, validate and normalize it at the boundary.

## Signals And Errors

- Use signals for async operations and UI-facing state changes.
- Store the latest error in `last_error` only as a convenience; do not make callers scrape logs.
- Return `bool` for start/queue methods and emit a signal for async completion.
- Include stable IDs such as package id, peer id, room id, or card id in errors where possible.

## Resource And File IO

- Use `user://` for downloaded/generated runtime data.
- Use `res://` for shipped project resources.
- Verify downloaded packages with SHA-256 before loading.
- Do not scan mounted update packs with `DirAccess`; rely on manifest metadata.

## Networking And Authority

- Keep public VPS room logic separate from private/Noray room logic.
- Do not let client update code modify authoritative server state.
- Do not run client hot update downloads on dedicated public servers by default.
- When a content or protocol mismatch is detected, block online join and guide the player to update.

## Comments And Language

- New code comments must be in English.
- Comments should explain why or what boundary is being protected, not restate the line below.
- Avoid broad comment banners unless they split a long existing file.

## Tests

- Add focused tests beside each new subsystem.
- Test pure helpers with headless scripts where possible.
- For Godot scenes/resources, prefer scene validation and Fennara validation when the relevant worktree is open in Godot.
- Every manifest schema change must update the manifest test and example manifest.

## Hot Update Specific Rules

- Treat `scripts/hot_update/*` as bootstrap code.
- Keep package schema changes backward-compatible or bump `schema_version`.
- Keep network compatibility changes behind `protocol_version`.
- Do not put large asset packages in `core_patch`.
- Package ids are stable family names; versions carry release cadence.

