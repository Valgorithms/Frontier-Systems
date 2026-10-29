# Design and engineering research

This is Frontier Systems' version-controlled knowledgebase for design decisions and bounded experiments. Research informs proposals; adoption belongs in the relevant design/architecture contract with measured acceptance evidence.

## Start here

| Entry | Topic | Outcome | Evidence limit | Next step |
| --- | --- | --- | --- | --- |
| [R-001: modern rendering optimization leads](entries/R-001-modern-rendering.md) | Rendering/performance | proposed | Official engine/vendor guidance and pinned source inspection; no reproduced rendering gains | [E-001: baseline and shared wall resources](experiments/E-001-rendering-baseline.md) |
| [Reference manifest](reference-manifest.csv) | Cross-topic provenance | existing registry | Each row states its reviewed scope and rights limits | Append targeted sources; preserve the CSV contract |
| [Foundational capability matrix v1](foundational-capability-matrix.v1.csv) | Engineering-game design | existing audit | Historical capability/gap statements have their own evidence dates | Revalidate a row before treating it as current implementation |

Use [the entry template](entry-template.md) for new investigations. Stable entry IDs identify a question, rather than each newly found URL. Search the index, manifest, design contracts and open research PRs before adding an entry; update an existing entry when the question/source is already covered.

## Existing knowledge and authority

- [Architecture contracts](../architecture/) describe owners and implemented boundaries.
- [Design contracts](../design/) distinguish direction from implementation, including [persistence and command boundaries](../design/persistence-and-command-boundary.md) and [bounded procedural worlds](../design/procedural-planets-and-memory-budgets.md).
- [Original planning notes](../../research_notes/Godot%20colony%20simulation%20plan/godot_architecture.md) remain historical research; this index links to them rather than copying or relocating them.
- [Performance reports](../../reports/performance/2026-10-09-baseline.md), [tick profiling](../architecture/tick-profiling.md) and [the simulation-rate matrix](../development/simulation-rate-benchmark-matrix.md) retain their original scope and caveats.

The manifest remains the shared provenance registry required by AGENTS.md. An external URL, video, benchmark screenshot or source-level optimization opportunity is not project performance evidence. Record author claims, independent source inspection, reproduced measurements and adoption decisions separately. Missing publication dates, inaccessible material, mutable documentation and incomplete coverage must stay explicit. Summarize independently; do not store full articles/transcripts or import code/assets without the project's rights review.

## Scope and research queue

Keep each pass bounded to one project decision and a practical way to disprove it.

| Topic | Bounded next question | Consult existing work first |
| --- | --- | --- |
| Rendering/performance | Can shared immutable wall resources improve a controlled workload? | R-001 / E-001 and the existing client benchmark |
| Simulation | Which measured owner/command work exceeds a tick budget? | Tick profiling and simulation-rate matrix |
| Persistence | Which interrupted checkpoint/retry failure needs stronger recovery evidence? | Persistence/command design and current checkpoint milestones |
| Multiplayer/networking | Which join/reconnect observation or bandwidth bound lacks exact-head evidence? | First-playable adapters and current observation contracts |
| Engineering-game design | Which repair/salvage/resource decision improves understandable recovery? | Capability matrix and survival/recovery design |

These are research questions, not approved runtime features. Prefer official engine documentation, papers with inspectable methods, and reproducible analyses. Videos supply leads; hardware/vendor advice must be evaluated against the actual renderer, API and target hardware.

## Weekly pass and handoff

The dedicated Frontier research task owns this index and its evidence updates. The parent coordinator owns scheduling; this document creates no automation. This workflow does not authorize disclosure of additional unfinished/private engine research, logs or credentials. Each weekly pass:

1. Read current AGENTS.md, this index, the manifest, affected contracts and open PRs through cloud tools. Pin the current integration commit; preserve desktop processes and working trees.
2. Revisit changed evidence and unresolved source gaps first. Deduplicate by URL/video ID, stable entry ID and research question; do not append unsupported links merely to show activity.
3. Investigate one bounded question using primary sources. Record access/version context, what was actually inspected, costs, limits and a reproduction/A/B proposal. An unrun experiment remains proposed.
4. Update the existing entry and manifest, retaining prior failures or superseded conclusions with dates. Propose at most one consolidated docs-only PR for the pass. Use a regular PR when the documentation slice is complete; reserve draft status for unfinished documentation or an actual unresolved blocker. If an equivalent PR is already open, update that research branch after checking its head rather than opening a duplicate.
5. Report PR/head, exact files, source/diff checks, measurements actually run, missing evidence and the next decision. Runtime experiments need separately authorized execution; this research workflow does not launch local games, benchmarks, GPU workloads or paid services.

Outcome vocabulary: **proposed** (hypothesis/plan), **tested** (bounded independent reproduction linked), **adopted** (decision accepted into a project contract), **rejected** (failed criterion or unsuitable tradeoff), **superseded** (replacement linked). Evidence can be source-checked while the outcome remains proposed. Record a decision date and scope for every transition.

Initial pass: **2026-10-25**; integration snapshot `b19e99ffd964006c4e590435239a8f17adbd62d5`. Existing research/design organization, manifest, renderer settings, wall presentation path, baseline report and CI scope were inspected through GitHub cloud reads. Runtime and visual acceptance were not exercised.
