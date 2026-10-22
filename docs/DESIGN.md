# Career Helper design

The five supplied interface images guide the new pearl-and-white surfaces, raised pill controls, soft panel shadows, generous rounded corners, system typography and restrained violet accents. These are visual estimates from screenshots, not measured design tokens. A ChatGPT-style sidebar remains because it was explicitly requested. Every screen continues to use shadcn/Radix components.

Swift is unnecessary for this browser app. System fonts, CSS surface treatment and accessible controls produce the requested visual direction while preserving the existing learning and career tools.

## Taavod brand

The user selected cyan and navy for the whole app on 22 October 2026. Primary colors are navy `#102B46`, cyan `#13B8D5` and ice `#E5F7FB`. The name is **Taavod**, with the tagline **Your next move**. `public/brand/taavod-mark.png` is the generated transparent brand asset, used in navigation, sign-in and browser metadata.

Built-in image generation produced the mark, then recolored it after the user's palette correction. Final edit prompt: preserve the rounded lowercase-t silhouette and curved negative-space separation; upper stroke cyan `#13B8D5`, lower stem navy `#102B46`; uniform flat fills, smooth edges, transparent square canvas, no words, tile, shadow, texture or purple. The superseded violet draft is not shipped.

## Animated Hen portrait

The user rejected the approximate procedural 3D face and approved the revised short-curl portrait on 21 October 2026. The shipped artwork is `public/companion/hen-fade-neutral.png`: compact dark curls, visible fade at the temples, strong brows and a short boxed beard. The renderer uses that exact image, preserving the approved likeness instead of rebuilding it from primitive shapes.

[PixiJS](https://pixijs.com/8.x/guides/components/scene-objects/mesh) renders a **2D facial rig**. Local pupil/brow deformations and masked eyelid/mouth keyframes animate the face. This is not a scanned or rigged 3D model. `src/lib/companion/bloub/` now contains the full framework-free Bloub animation engine; its sampled gaze, blink, expression transitions, wink and thinking pulse drive the portrait adapter. The engine adds a documented numerical `rig` output to avoid recreating its timing in a second animation system.

The head blinks and follows the pointer, winks on click, changes expression for practice feedback and animates its mouth while coach text streams. Text activity is not audio lip sync. Reduced motion displays the unchanged approved neutral artwork. Off-screen and hidden views pause, rendering is capped at 30fps and pixel density at 2, and each renderer releases its resources on unmount. The exact approved artwork also appears while the renderer loads or if graphics support is unavailable.

Current assets, generated with the built-in image tool:

- `public/companion/hen-fade-neutral.png`: approved portrait refinement using Hen’s real portrait plus the earlier clay head. Prompt: preserve tactile clay styling, match short curls with a close side fade, strong brows, natural facial proportions, a short neat boxed beard, head only on transparency.
- `public/companion/hen-fade-blink.png`: edit the approved portrait’s eyelids only to form a closed-eye blink; preserve alignment, hair, face, lighting and smile. Used only inside feathered eye masks.
- `public/companion/hen-fade-speaking.png`: edit only the mouth to a modest open speaking shape; preserve all other features. Used only inside the mouth mask.

The earlier oversized-curl exploration and procedural geometry are superseded. The source photograph stays in the portfolio project and is not a public app asset.

## Image explorations

Built-in image generation produced `design/explorations/hen-clay-body.png` and `hen-clay-head.png`. These are retained as design references; the shipped companion renders live meshes and does not use them as its animated surface. The source portrait and old Hen Helper icon remain in their original projects and are not copied into the public app.

Prompts used, in order:

1. Generate an original welcoming full-body clay Hen from his portrait and previous avatar: dark short curls, beard, navy collared shirt, beige trousers, rounded toy proportions, transparent background.
2. Refine the same character toward matte hand-sculpted clay, simplified curls and compact proportions; remove the background and halo.
3. Generate the same character's head only, preserving curls, eyebrows, beard and coloring; front-facing, friendly, fully visible ears and chin, transparent background.

The built-in image tool was used for the explorations and current facial keyframes. Early explorations remain for provenance; the approved fade portrait and facial keyframes listed above are the shipped assets.
