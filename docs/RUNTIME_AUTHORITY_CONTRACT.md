# Runtime Authority Contract

Date: 2026-06-26

This contract is the implementation rule for multiplayer performance work. It preserves the current character skills while making every hot system declare where it is allowed to run.

## Runtime Roles

| Runtime role | Owns | Must avoid |
| --- | --- | --- |
| Owner client | Input sampling, local camera, local HUD, local-only feedback, optional prediction | Authoritative damage, room state, global card consumption |
| Server room | Match state, card consumption, damage, death, spawn, room settings, validated skill effects | GPU painters, screen overlays, local audio/VFX, repeated remote visual scans |
| Remote client | Rendering replicated state and low-cost interpolation | Re-running owner-only visibility, targeting, paint projection, or authority checks |
| Headless public server | Server room authority without visual/audio work | Client media, editor helpers, Steam UI, Terrain3D, GPU-only systems, debug spam |

## System Boundaries

| System | Owner client | Server room | Remote client | Headless server |
| --- | --- | --- | --- | --- |
| Player movement | Sample input and local feel | Validate/relay compact state | Interpolate and infer animation | State only |
| Weapon fire | Send aim intent | Raycast, damage, ammo authority | Render tracer/impact | No tracer/impact VFX |
| Card draft/loadout | UI choice request | Draft, keep, consume, activation event | UI sync only | State only |
| Card effects | Local feedback for owning player | Authoritative gameplay effect execution | Render replicated effect state | No local UI/VFX |
| Hunter flashlight | Thresholded pose intent | Validate/forward pose/state | Render synced light | No light node/VFX |
| Hunter turret | Owner UI/feedback | Target scan, legality, damage | Render synced events | No model/audio/projectile VFX |
| Stalker visibility | Owner-computed visibility | Receive/forward compact state | Render synced visibility | State only |
| Chameleon paint | Owner projection/GPU draw | Validate and forward compact batches | Render received paint | No GPU painter |
| Map props | Owner impact request | Physics authority and coalesced sync | Kinematic render state | Physics authority only |

## Coding Rules For New Work

- Use explicit static types for new and touched variables, return values, and meaningful local values.
- Keep `Network` authoritative for lobby state, card draft, card consumption, room settings, and public server routing.
- Keep `player.gd` as a facade. New behavior should move into controllers that receive the player as a context, not into more match blocks on the root character script.
- Never add a per-frame scan on remote clients when the owner or server can publish compact state.
- Never create CanvasLayer, AudioStreamPlayer, particles, GPU painter resources, or high-poly preview nodes on a dedicated public server.
- Cache reusable local feedback nodes and clear queued work when a skill is inactive, the owner changes role, or the node exits the tree.
- Prefer batching, thresholds, and fixed intervals for network events. Every repeated RPC path needs an event budget and telemetry key.

## Memory And Cleanup Rules

- Long-lived controllers should be owned by the player facade and reused; avoid recreating controllers every activation.
- Temporary VFX, decoys, overlays, tweens, and audio players must have a clear end condition and must call `queue_free()` or be explicitly hidden and reused.
- Timers stored in dictionaries should erase expired keys during processing.
- Large paint/image buffers should be bounded by surface count and byte size, and cleared when previews are committed or canceled.
- Server export packages must keep editor helpers, test-only assets, Terrain3D resources, and client-only media out of the dedicated server path.

## Current First Step

`PlayerCardEffectController` now owns card effect routing. `Network` still owns draft/loadout/consumption authority, and `player.gd` keeps only the public `apply_card_effect(card_id)` facade plus existing effect hooks. This is intentionally conservative: it moves the high-change card match out of the character root without changing card behavior.
