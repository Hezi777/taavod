# Design notes

Taavod is a native SwiftUI app. The main visual reference is Revolve: a near-black canvas, charcoal surfaces with restrained gradients, crisp neutral typography, fine borders, and purple for active emphasis. The layout should feel information-dense while leaving enough space for reading and editing.

The shared adaptive colors and card styles live in `native/Taavod/UI/DesignSystem.swift`. Dark mode uses a near-black canvas and charcoal surfaces; light mode keeps neutral off-white page backgrounds and white cards. Purple remains the primary accent in both appearances. Keep category fills neutral; reserve purple for active emphasis and use text/icons to explain state.

Keep radii and borders consistent across cards, use compact headings instead of repeating large page titles, and let content determine the hierarchy. Keep glass effects around navigation and controls; reading, code, and editing areas need solid surfaces.

Motion should be short and purposeful. Hover borders ease over 140 ms and press feedback over 120 ms. Disabled controls suppress interactive styling. Use the reduced-motion setting for entrance effects and stop ongoing mascot or runtime activity when the app is inactive. Avoid animating repeated navigation and keyboard actions.

## Mascot status

The current app icon is the Shih Tzu PNG in `native/Taavod/Assets/AppIcon.icon/Assets/`. The floating Coach portrait and chat header scrub the bundled `FlowHeadScrub.mp4` clip across the app window, using the existing portrait image as the poster. The clip contains mixed head directions, so its timeline is not an exact gaze control. `SparkMascot` retains its SceneKit Shih Tzu model as development artwork. The original source photo and personal workspace data do not belong in the repository; approved derived mascot artwork may be included.
