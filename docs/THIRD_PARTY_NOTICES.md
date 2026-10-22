# Third-party notices

The browser SQL runtime redistributes PGlite from the installed `@electric-sql/pglite` package. PGlite is maintained by Electric DB Limited and distributed under Apache License 2.0. The license is retained at [PGlite-APACHE-2.0.txt](legal/PGlite-APACHE-2.0.txt); runtime assets are copied without modification at build time. See [the upstream project](https://github.com/electric-sql/pglite) for PostgreSQL and bundled dependency notices.

Pyodide and its Python packages are loaded from their pinned upstream distribution. See [Pyodide licensing](https://github.com/pyodide/pyodide/blob/main/LICENSE) and the licenses of packages provided by that distribution.

Other application dependencies retain their upstream licenses. These notices do not grant an open-source license for Career Helper or its private content.

## Bloub animation engine

`src/lib/companion/bloub/` vendors the framework-free engine from [Jérémy Perret’s Bloub](https://github.com/jeremy-prt/bloub), commit `b4bb3c1b5f93c7b87a2e8d620f667c4093d97749`, under MIT. Full notice: [Bloub-MIT.txt](legal/Bloub-MIT.txt). `engine.ts` adds a `rig` output containing its already-sampled numerical pose, so the approved portrait layers can consume the same gaze, blink, expression and state-transition values. Other engine modules retain their upstream implementation. The original x.ai-inspired silhouette is not displayed. No affiliation with x.ai is claimed.

## PixiJS

[PixiJS](https://pixijs.com/) 8.22.0 renders the approved portrait as a 2D facial rig. License: MIT; full upstream notice is retained at [PixiJS-MIT.txt](legal/PixiJS-MIT.txt).

## Pagila core exploration database

`public/practice/datasets/pagila-core.sql` contains the 15 core tables and their sample rows from [Pagila](https://github.com/devrimgunduz/pagila), pinned at `ce6e114236bb828e5ec0dc835f65f1bf1b9179f5`, under the [PostgreSQL License](legal/Pagila-PostgreSQL.txt). `scripts/prepare-pagila.mjs` preserves core data while flattening payment partitions and omitting extensions, operational defaults, views, functions and triggers for browser use. The generated column uses stored rather than virtual generation. The manifest records row counts and a dataset checksum. This public sample data is separate from Hen’s private workspace and from the synthetic grading fixtures.
