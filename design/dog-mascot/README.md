# Taavod Shih Tzu mascot

The active mascot uses the approved premium Shih Tzu render in `flow/`. The dashboard scrubs the supplied head-motion clip across the app window, while small placements use a static portrait. The app icon is the layered Icon Composer document at `native/Taavod/Assets/AppIcon.icon`; its foreground comes from `flow/shih-tzu-icon-v2.png`.

The bundled `FlowHeadScrub.mp4` is silent H.264 with every frame encoded as a keyframe. Its mixed head directions provide timeline scrubbing rather than exact directional gaze. Source photos and private workspace data are excluded from the repository.

`BuildMascot.swift`, `ShihTzu.scn`, and the bundled USDZ retain the earlier procedural SceneKit exploration. Regenerating that exploration writes its old icon output, so preserve the current approved icon before using it. It does not generate the active portrait or video.

Motion attribution is in `NOTICE.md`.
