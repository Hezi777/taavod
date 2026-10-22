# Learning workbench

The learner should be able to inspect the data, make a prediction, write code, run it, examine the result and explain the outcome before saving evidence. Opening a lesson is not a pass.

## Product references

Reviewed primary product pages on 22 October 2026; the exercises and explanations in Taavod remain original or attributed to their existing sources.

| Reference | Useful interaction | Taavod application |
|---|---|---|
| [SQLBolt SELECT lesson](https://sqlbolt.com/lesson/select_queries_introduction) | Short explanation followed immediately by a concrete task, table inspection and an editable query. | Focused lesson stages, live query editor and visible output contracts. |
| [SQLZoo SELECT basics](https://www.sqlzoo.net/wiki/SELECT_basics) | Introduce the actual table and modify a working query in small steps. | Inspect schema and real rows before attempting a join; use progressive hints. |
| [DataCamp SQL introduction](https://www.datacamp.com/courses/introduction-to-sql) | Small theory/practice units and explicit learning outcomes. | One recommended session, separate exploration and checking, and a review step. |

These patterns informed the interaction design; they are not evidence that this app produces equivalent educational outcomes.

## Data and execution

- Exploration uses actual PostgreSQL through PGlite, with 15 core Pagila tables and 121,209 public sample rows. It loads on demand in an isolated browser worker, independently of private Supabase.
- The relationship map and completion schema come from introspecting the shipped seed. The manifest includes exact row counts, source revision and checksum.
- Payment partitions are combined into one table. Operational defaults, triggers, views, extensions and server functions are excluded. The source is a sample database, not production customer data.
- Grading uses two independent synthetic fixtures, including edge cases, rather than treating a plausible-looking result on one dataset as proof. Exploration does not award a pass.
- Modeling, pipeline replay and conversion labs are clearly identified illustrations. Their totals are calculated from the shown records; they do not claim to execute Power BI, DAX or ETL infrastructure.

## Interactive teaching examples

- Sales grain: repeat an order total across lines, then switch to line amounts and filter a product category. Compare 280 with the valid 180 total.
- Pipeline replay: load the same source batch twice with append or keyed upsert, then correct an existing record and replay it.
- Weighted conversion: change a store's eligible population to see why a visitor-level rate differs from an equal-store average.
- SQL: change join/count choices in the small lesson illustration, then transfer the idea to executed PostgreSQL queries and independent validation fixtures.

## Verified behavior

The final browser pass executed real full-sample SQL queries and table previews, checked correct and wrong exercise answers, displayed syntax failures, stopped a long-running query, verified keyboard execution and editor locking, and inspected desktop/mobile and dark layouts. Python’s revenue exercise also passed through the CodeMirror editor and the actual Pyodide worker; its editor was non-editable during execution. No QA attempt was saved to the private workspace.

Type checks, lint and all 111 tests pass after integration. Tests include the shipped core seed, enforced foreign keys, reconciled revenue, exact schema metadata, original grading fixtures and the interactive example calculations.
