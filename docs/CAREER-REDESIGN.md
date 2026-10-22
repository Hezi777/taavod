# Career screens redesign

## Direction

The reference set uses a pale gray work surface, bright white content planes, a strong focus surface, and small pastel signals. Taavod uses a navy and cyan identity to make the next useful action obvious while keeping real progress and private data central.

## Compact design DNA

- **Color:** canvas `#F3F4F7`, ink `#102B46`, paper `#FFFFFF`, cyan `#13B8D5`, focus navy `#12344D`, and pale ice `#E5F7FB`; mint and coral remain reserved for meaningful status.
- **Type:** system sans; 34px page titles, 21px section titles, 14px body, 12px supporting text. Sentence case and left alignment.
- **Layout:** 260px collapsible navigation (68px compact), up to 1420px content, a 12-column working grid with a narrow contextual rail. At mobile widths, stack content and use the existing accessible drawer.
- **Shape and depth:** 14–22px radii based on hierarchy; hairline borders define white surfaces; one restrained shadow for raised panels and controls.
- **Style:** calm career workspace with measured density. Use a high-contrast navy focus panel as the memorable surface, then reserve pastel fills for specific status or progress context. Dark mode uses navy surfaces `#081B2C`, `#102B40`, and `#0C2235`. No decorative sample charts or fabricated metrics.
- **Effects:** CSS only, short action feedback, visible focus, reduced motion respected.

## Composition sketches

Today: `navigation | greeting + navy next-session panel | weekly route + contextual rail | career actions`

Jobs and interviews: `navigation | page heading + stage summary | filterable work list | selected job or rehearsal panel`

Portfolio and settings: `navigation | page heading | content grouped by task | supporting profile / provider context`

The asymmetry creates a clear place to start, while each screen keeps its own real workflow and data. On narrow screens, panels become a single left-aligned column.

## Review against the references

The references contain sample people, meetings, percentages, and charts. Those are not product data, so the redesign borrows their panel hierarchy and pastel palette while using actual profile, task, job, and attempt records. The implementation stays within the existing career workflows and does not add illustrative statistics.
