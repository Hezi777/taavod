# Third-party notices

The native app downloads pinned PGlite 0.5.10 files on demand into the user's local runtime cache. PGlite is maintained by Electric DB Limited and distributed under Apache License 2.0. The license is retained at [PGlite-APACHE-2.0.txt](legal/PGlite-APACHE-2.0.txt). The bundled manifest records the exact upstream URLs and SHA-256 hashes. See [the upstream project](https://github.com/electric-sql/pglite) for PostgreSQL and bundled dependency notices.

Pyodide and its Python packages are loaded from their pinned upstream distribution. See [Pyodide licensing](https://github.com/pyodide/pyodide/blob/main/LICENSE) and the licenses of packages provided by that distribution.

Other application dependencies retain their upstream licenses. These notices do not grant an open-source license for Taavod or its private content.

## Bloub animation engine

The original React implementation, preserved at the `legacy-react` tag, vendors the framework-free engine from [Jérémy Perret’s Bloub](https://github.com/jeremy-prt/bloub), commit `b4bb3c1b5f93c7b87a2e8d620f667c4093d97749`, under MIT. The native prototype's gaze and blink timing is informed by this behavior. Full notice: [Bloub-MIT.txt](legal/Bloub-MIT.txt). The original x.ai-inspired silhouette is not displayed. No affiliation with x.ai is claimed.

## PixiJS

[PixiJS](https://pixijs.com/) 8.22.0 was used by the archived React portrait renderer. It is not a dependency of the native app. Its MIT notice remains available at [PixiJS-MIT.txt](legal/PixiJS-MIT.txt) for the archived implementation.

## Pagila core exploration database

`native/Taavod/Resources/datasets/pagila-core.sql` contains the 15 core tables and their sample rows from [Pagila](https://github.com/devrimgunduz/pagila), pinned at `ce6e114236bb828e5ec0dc835f65f1bf1b9179f5`, under the [PostgreSQL License](legal/Pagila-PostgreSQL.txt). The archived preparation script preserves core data while flattening payment partitions and omitting extensions, operational defaults, views, functions and triggers. The generated column uses stored rather than virtual generation. The native app also bundles a PGlite snapshot for fast exploration startup. The dataset manifest records row counts and the SQL checksum. This public sample data is separate from the private workspace and synthetic grading fixtures.
