# Career Helper UX review

The product should answer one question quickly: what is a useful next step for Hen today? The supplied references call for a neutral Apple-like workspace with soft white surfaces, pill controls, restrained shadows, readable system typography, and a quiet companion. ChatGPT's navigation supplies the interaction model: a flat sidebar that can become a compact rail.

## Decisions by screen

| Screen | Change and purpose |
| --- | --- |
| Navigation | Move collapse/expand to the top, keep it usable in both states, persist the choice, and remove the oversized workspace switch. Use familiar search, new conversation, grouped destinations, and an account footer. Expanded width is 260 px; compact rail is 68 px. |
| Today | Replace the slogan and four equally prominent counters with one recommended session. A first-time learner gets the same 25-minute guided SQL lesson as Learn. Keep the weekly checklist, direction, follow-ups, and practice evidence below it. |
| Learn | One recommended session followed by a readable skill library. Lessons separate understanding, a worked example, trying a problem, and reviewing it. The first worked example includes an interactive join/count illustration. |
| Practice | One next exercise, then a progressively disclosed exercise list. Problem and feedback have priority over reference/schema material. Real code checks remain distinct from self-review. |
| Jobs | Default to current saved roles, with imported historical leads available through an explicit filter. Use compact list rows, a small activity summary, and an empty state offering Save a job or Discover. Preserve source and freshness information. |
| Portfolio | Replace decorative monogram cover images with project category, status, evidence, and a preparation action. Keep claims and caveats visible. |
| Interviews | Show the choose → draft → review workflow, a focused scenario, optional timer, a proper writing area, and a review guide. |
| Coach | Keep the coach available from a persistent corner launcher, with compact and expanded views of the same conversation. Put saved conversations above the messages and the provider/model picker inside the composer. Keep the composer visible while messages scroll. |
| Settings | Use functional names, comfortable forms, a visible save action, and clearly separated profile, connections, documents, and workspace areas. |
| Onboarding | Keep three explicit steps with a realistic time commitment. Correct confidence identifiers so metrics and Git answers match the curriculum. |

## Shared interaction rules

- Navigation labels and page headings use the same names.
- Primary actions use a dark pill; violet is reserved for small accents and progress.
- Avoid turning every piece of information into a separate card. List separators carry structure where appropriate.
- Controls retain visible focus, accessible names, active-page state, and reduced-motion support.
- The mobile navigation makes the main workspace inert, traps focus, closes on Escape, and returns focus to its trigger.
- Loading states avoid briefly presenting zero activity as loaded data.
- A reading visit never counts as a verified practice pass.

## Verification performed

Playwright CLI used an isolated owner-authenticated `career-ux` session against local Supabase. Screens were sampled at 1440 × 1000 and 390 × 844 in light and dark themes.

- Today, Jobs, Portfolio, Interviews, Coach, Settings, Onboarding, Learn library, and Practice library were inspected for layout and horizontal overflow.
- A deep lesson initially overflowed on mobile because its lesson navigation established an intrinsic grid width. This was fixed with constrained grid/aside widths and scrollable lesson navigation.
- Sidebar collapse reached 68 px, remained 68 px after reload, and expanded to 260 px. Width changes are immediate to avoid stretching the restored compact layout during hydration.
- Mobile navigation correctly applied inertness and returned keyboard focus after Escape.
- Coach composer bottom was 766 px in an 844 px viewport; long starter content scrolls above it.
- The join illustration actually changed results: left join plus COUNT(*) gave the unmatched customer 1, inner join removed that customer, and COUNT(payment_id) gave 0.
- Type checks and lint passed after the changes. Root verification covers the full integrated build and practice execution.

Captures are local, ignored QA artifacts under `output/playwright/ux-*`.

## Coach available throughout the workspace

The bottom-right launcher opens a modeless compact coach window. Expand increases the same window to a full chat surface; minimize returns it to the corner. Closing the window keeps the conversation controller mounted in the workspace layout, so a draft, model choice, response in progress, and conversation survive reopening and navigation. The visual dialog itself unmounts on close, preserving Radix focus/dismissal behavior without leaving a hidden dialog layer behind.

The composer takes the supplied component reference's rounded, growing text area and compact model pill. It uses real Claude/Groq model lists from the existing authenticated server endpoints. Provider keys stay server-side. Loading, retry, disconnected-provider setup, and unavailable saved-model states are explicit; no example model IDs, voice simulation, effort toggle, or attachment feature was copied. Model selection applies to the current conversation request and does not silently replace the saved provider default.

The compact coach does not block the underlying workspace or move the page when new tokens arrive. Setup links close the window so the destination settings are reachable. Message scrolling stays inside the coach.

## Final integration checks, 22 October 2026

The final identity is Taavod, using cyan, navy and ice surfaces. Career routes were inspected at 1440 and 390 pixels; the sidebar measured 260/68 pixels expanded/collapsed. The small mobile coach launcher no longer covers the Settings save action and hides while the navigation drawer is open.

Coach checks verified draft retention through expand/minimize/close/reopen, provider setup states, and a genuinely new conversation from the sidebar. Mocked model-list and chat responses verified Claude and Groq model IDs in request payloads and retained an in-flight response across window changes. Both conversation writes were intercepted; no test conversation was written to Hen’s records. No live provider API call was made.

The coach uses custom positioning without the centered dialog’s translation classes. This fixes off-screen controls caused by combining a corner anchor with the default dialog centering transform. The normal centered dialogs retain their default placement.
