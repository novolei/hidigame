# Polygon Apocalypse City Sector Plan

This city is used for a third-person multiplayer prop-hunt escape game, so sectors are designed around readable chase routes, disguise density, hunter sight lines, and late-match escape pressure rather than equal geometric slices.

## Principles

- Keep the full Unity city and URP city as archive/showcase maps.
- Use smaller sectors for normal matches so hunters can search decisively and props can rotate without crossing an empty megamap.
- Preserve skyline, cloud ring, mountains, ocean, and semi-circle backdrop props across sectors so each slice still feels like the original Unity scene.
- Prefer looped routes over dead-end arenas: each sector should have at least two escape rotations and several short third-person sight breaks.
- Tune sectors by player count:
  - 6-10 players: compact clue-reading and high prop density.
  - 8-12 players: larger loops, mixed vehicle/building cover, and riskier hunter sight lines.
  - 16-24 players: full city variants or future stitched multi-sector events.

## Playable Sectors

| Sector | Scene Theme | Bounds X/Z | Recommended Players | Prop Hunt Escape Intent |
| --- | --- | --- | --- | --- |
| `downtown_core` | Downtown Escape | X -40..150, Z -120..40 | 8-12 | Dense shopfronts and car clutter. Props can chain disguises through storefront debris; hunters get short but frequent sight checks. |
| `quarantine_crossing` | Quarantine Crossing | X 105..230, Z -70..70 | 6-10 | Checkpoint walls and hospital props create pressure lanes. Props survive by using side exits and bus cover instead of hiding forever. |
| `market_row` | Market Row | X -220..45, Z -80..110 | 6-10 | Smaller, prop-rich street row for fast rounds. Strong disguise density, shorter escape distance, and fewer long sniper-like views. |
| `overpass_camp` | Overpass Camp | X -25..220, Z -260..-120 | 8-12 | Bridges, trucks, and caravans make a chase map with vertical silhouettes and shadow cover. Good for Stalker/Chameleon mind games. |
| `warehouse_ward` | Warehouse Ward | X -70..120, Z -230..-50 | 8-12 | Industrial clutter and burned-house routes. Supports close third-person peeking, quick corner breaks, and tense final extraction loops. |

## Implementation Notes

- `scripts/polygon_apocalypse_map.gd` exposes `sector_id` for city maps.
- Sector scenes reuse the original Unity-migrated layout JSON and filter spawned objects at runtime.
- URP sector scenes use the same sector IDs with the `city_urp` material calibration.
- Far skyline objects are included outside sector bounds by name tokens so the scene does not feel like a cropped debug chunk.

## Next Gameplay Layer

The current implementation slices renderable/collision content. The next layer should add sector-aware spawn and objective metadata:

- Prop spawn clusters: near dense clutter, not directly on extraction paths.
- Hunter spawn: offset toward the sector edge with 2-3 second line-of-sight protection.
- Escape exits: two normal exits plus one risky late-match exit per sector.
- Dynamic lockdown: close one route after prep to make repeated rounds less solved.
