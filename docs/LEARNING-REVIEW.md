# Learning experience review

Reviewed 21 October 2026 for a BI Developer / BI Engineer refresher, with a four-hour weekly budget. This change preserves the existing 10 tracks, 30 lessons and 81 exercises; it improves their teaching structure and makes one useful next action visible.

## What changed

- The library recommends one session with a concrete outcome and combined reading/practice time, followed by a readable skill list. It no longer presents ten competing course cards.
- Every lesson now has an outcome, a prediction question with a revealable explanation, three steps of reasoning, a specific misconception and a related practice task.
- Sessions follow Understand → Worked example → Try it → Review. Reading does not award practice credit. Saved results remain independent, assisted or self-reviewed.
- The first SQL session includes an interactive tiny example comparing LEFT / INNER JOIN and COUNT(payment_id) / COUNT(*). The example is explicitly illustrative; it does not impersonate the runtime fixture.
- The practice library suggests one challenge, initially shows eight tasks, and offers search, a skill selector and more results on demand. The execution, cancellation, reset, fixture checks, draft persistence and progressive hint behavior remain intact.
- All 19 runnable SQL prompts now state their required output columns and result-set order before revealing a solution. Previously learners had to view the answer to discover the grading contract, which also marked the attempt as assisted.
- Recommendations start with preserving unmatched rows, continue through the linked tasks, and prioritize a failed linked task. This is a deterministic next-step rule, not an inferred proficiency score. A self-reviewed or assisted pass may move the suggested session forward but never becomes an independent verified completion.

## Research and teaching decisions

The content is original explanation and practice built around the official references already linked from each lesson. No paid course material was copied.

| Primary source | What it supports | Application here |
| --- | --- | --- |
| [IES: Organizing Instruction and Study to Improve Student Learning](https://ies.ed.gov/ncee/wwc/PracticeGuide/1) | Worked examples interleaved with problems, delayed practice, retrieval and explanatory questions. | Prediction before reveal, a worked reasoning sequence, an immediately related task and the existing delayed review queue. The guide concerns instruction broadly; it does not prove outcomes for this app. |
| [PostgreSQL: Joins Between Tables](https://www.postgresql.org/docs/current/tutorial-join.html) | Pairing rows and preserving unmatched rows with outer joins. | Tiny controllable join example, explicit grain, null-key count reasoning and a related anti-join task. |
| [PostgreSQL: Window Functions](https://www.postgresql.org/docs/current/tutorial-window.html) | Window functions retain rows while calculating over related rows. | Monthly grouping before LAG, observed-month versus calendar-month distinction, and deterministic tie behavior. |
| [Microsoft: Star schema guidance](https://learn.microsoft.com/en-us/power-bi/guidance/star-schema) | Fact and dimension roles, granularity, relationship design and historical dimensions. | Model the business process before choosing visuals; separate incompatible fact grains and illustrate event-time Type 2 lookup. |
| [Microsoft: Model relationships in Power BI Desktop](https://learn.microsoft.com/en-us/power-bi/transform-model/desktop-relationships-understand) | Relationships propagate filters; they do not enforce data integrity. | Check dimension key uniqueness, begin with a clear dimension-to-fact path and reconcile totals before using charts. |
| [Microsoft: Modify DAX filter context](https://learn.microsoft.com/en-us/training/modules/dax-power-bi-modify-filter/) | Filter context, CALCULATE, filter modifiers and context transition; model and measure prerequisites. | Model-first sequence, January/Bikes denominator walkthrough and explicit tests for removed versus retained filters. |

Sources above were checked during this review. Existing lesson links also point to official dbt, pandas, Python, Power Query, Qlik, NIST, Git and technical-writing documentation. The older IES guidance remains a source for the instructional pattern, not a claim that every learner needs the same sequence.

## Verification

- Nine practice tests pass: all SQL reference solutions execute against both fixtures; non-equivalent revenue queries are rejected; all 30 teaching guides resolve a task in the same skill; each SQL task exposes its output contract; recommendation start/advance/retry behavior is covered.
- Project type check and scoped ESLint pass after the component changes.
- End-to-end visual and interaction review is coordinated with the overall UI/UX agent; final results are recorded by the parent task after integration.

## Deliberate limits

- Power BI and Excel tasks require the actual tools; the browser does not execute DAX or `.pbix` files. These tasks retain rubrics and evidence uploads.
- Qlik is a conceptual refresher in the browser. Qlik scripts are examples, not executable Qlik sessions.
- Predict/reveal checks are retrieval prompts, not scored assessments. The interactive join lab teaches one mechanism and is separate from the actual SQL runtime.
- This is a targeted refresher, not an official credential or a claim of production readiness. Progress reflects saved evidence, not reading time or an invented skill score.
