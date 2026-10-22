# Avatar options

Reviewed 22 October 2026. The requirement is Hen’s short curls, faded sides, beard and approved face, with real animated expressions. The current portrait keeps the exact approved artwork and uses the open-source PixiJS renderer plus Bloub’s animation engine.

| Option | What it supplies | Fit for this app |
|---|---|---|
| [Bloub](https://github.com/jeremy-prt/bloub) + [PixiJS](https://github.com/pixijs/pixijs) | Animation timing, gaze, blinks, expression transitions and a 2D mesh renderer | Already integrated; preserves the approved likeness. |
| [Mesh Avatar Studio](https://github.com/shinshin86/mesh-avatar-studio) | MIT tools for turning an illustration into a layered, animated 2D mesh | Closest alternative to the current portrait approach. Its editor adds a preparation workflow, rather than an Apple Memoji asset library. No additional runtime needed for the current rig. |
| [three-vrm](https://github.com/pixiv/three-vrm) | MIT loader, expression and look-at support for VRM models | Requires a separately authored custom VRM model; does not generate Hen’s haircut or likeness. |
| [TalkingHead](https://github.com/met4citizen/TalkingHead) | MIT 3D animation and audio lip-sync runtime | Requires an appropriately rigged GLB and facial blend shapes. Adds little to a text-only coach without that model. |
| [DiceBear](https://github.com/dicebear/dicebear) | Seeded SVG avatars with configurable traits | Useful for generic onboarding avatars, but does not reproduce the approved clay head or provide its animation. |

Research did not locate an official open-source Apple Memoji renderer for this React web app. An avatar library alone does not supply an accurate custom head. Keep the approved portrait and existing open-source animation path; do not replace it with a generic preset. This remains an animated 2D rig, not a scanned 3D model or audio lip-sync system.
