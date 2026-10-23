# Finite default-start enclosure acquisition: design review

Base: `5d57ed7d68c73018d2df42e069ebab85fc8af59c` (PR144 implementation merge
`4e6b463fdd4d769c5c48c41bcfe3d735fde4eb34`).
Owner: worker `01a16a3c-873a-7be2-987a-768ddd5d6a42`.
Coordinator `01a1283c-45d6-7e61-bedd-905e8797f03d` owns design acceptance,
leases and merges. Status: proposal only; no runtime/schema edits authorized.

## Outcome and verified prerequisites

A player acquires finite raw matter, refines it, and builds the existing basic
7.6 kg enclosure, 2 kg fabricated crowbar and 0.2 kg seal through authenticated
commands, without test seeds. Retain existing bills and material yields.
Roadmap ordering in milestone-coordination.md prioritizes finite engineering and
recovery; civilization-to-space-progression.md also prioritizes environmental
extraction, container storage, refining and recycling.

Source inspection establishes a missing resource prerequisite, not a missing UI
button. Production catalog v1 contains exactly 10 kg ore, 5 kg ice and 10 kg
regolith. Mounted `mine`, direct `extract`, `tool_extract` and sustained tool
extraction debit the same finite deposit. Refining 1 kg ore produces 0.6 kg iron
and 0.4 kg tailings. Regolith yields salts/silicate/tailings; it supplies no iron.
TerrainSimulationSystem commissions only 2 kg dirt in a new world, zero in legacy
recovery; portable receipts are pinned to dirt and retain terrain ownership.
The moon/Mars material definitions are metadata, not commissioned ore sources.
Equipment salvage requires an existing Production structure material record;
legacy starter inventory is not a reclaimable source of fabricated iron bills.
Recycling cannot increase net available iron. No existing acquisition path can
therefore close the deficit without a content/commissioning policy change.

## Exact budget

All quantities below are integer milligrams; displayed kg are exact.

| Budget item | Existing default | Minimum proposed new-world source |
| --- | ---: | ---: |
| Ore available | 10 kg | 17 kg total, including a distinct finite 7 kg seam |
| Complete 1 kg refine batches | 10 | 17 |
| Refined iron | 6 kg | 10.2 kg |
| Retained tailings | 4 kg | 6.8 kg |
| Enclosure + crowbar + seal | 9.8 kg | 9.8 kg |
| Remaining iron | deficit 3.8 kg | 0.4 kg |

The algebraic deficit requires 6.333334 kg additional ore, but the existing 1 kg
recipe consumes whole batches; seven additional batches are the smallest usable
increment. Existing new-world Production matter is 25 kg; a distinct 7 kg seam
would make that budget 32 kg. Terrain's separate 2 kg is unchanged. This is an
explicit increase in finite world-resource commissioning, not an existing path
or a permitted implementation under the current no-bootstrap-inflation scope.
No alternate recipe, replenishment, free depot credit or salvage relabeling is
proposed. Crafting eight 1 kg plates for a 7.6 kg plate bill can leave 0.4 kg plate
rather than 0.4 kg raw iron; acceptance must assert actual retained identities.

## Proposed smallest complete acquisition slice, subject to review

Prefer a separately identified finite iron-ore outcrop using the existing
Production acquisition/carrier/refinery transaction paths. Do not extend the
homogeneous dirt owner into an ore converter or introduce a Terrain-to-Production
mass bridge merely to fund this room. Production already owns ore sources and
all downstream conserved stock. Inventory continues to own physical carriers,
body/reach/hand authorization; Tools owns active extractor capability and wear.
Keep acquisition at fixed-tick command ingress and Production at priority 300;
use its existing bounded counters, exact-intent receipts and capacity claims.

Before implementation Coordinator must explicitly accept or replace the 7 kg
new-world commissioning policy and source placement/reach. A source near the
existing iron location must be separately selectable and observed. Never silently
change `deposit.iron`, catalog v1 or its historical 25 kg invariant. A versioned
catalog plus save origin-budget/version policy must distinguish new 32 kg worlds
from historical 25 kg worlds. Legacy restore gets zero new seam mass; it cannot
upgrade an old world into a new 7 kg grant. Decode immutable historical catalogs
and fingerprints explicitly, retain old schemas, reject unknown fingerprints,
invalid budgets and depleted-source resets. Exact snapshot shape is deferred
until review; no claim that adding a catalog row alone is sufficient.

Bound scope: Production source/catalog/save validation, existing source selector
observation/UI allowlists, focused integration/schema tests, architecture and
this milestone contract. No pressure/access geometry changes, new owner, service,
asset, dependency, environment variable or terrain material conversion.

If new finite world matter remains prohibited, this task cannot deliver the full
room under the current bills. The smallest truthful fallback is an acquisition
budget regression and player-facing exhausted/insufficient-source guidance,
with a negative control proving the default 6 kg ceiling. That fallback must be
named as prerequisite evidence, never full default-start enclosure acceptance.

## Acceptance and proposed bounded checks

Positive: pristine new-world initialization only; acquire through real source
commands into an owned canister; unload and refine 17 complete batches with
unchanged yields and paid energy; build the established paid enclosure/crowbar/
seal via current commands; retain all tails, leftovers, energy and source
balances. Commission the supported room through the existing authenticated path.
No direct owner snapshot seed or store edit in the positive acceptance flow.

Negative controls: exhausted source, no working tool/owned carrier, foreign actor,
stale revision, out of reach, full carrier, power/energy shortage, replay and
changed-payload retry; each failure leaves material owners unchanged. Save/reload
partly depleted and exhausted sources; reject injected origin budgets, unknown
catalog/version, duplicate source mass, forged receipts and legacy grant attempts.
Keep reservation-spend guards and whole-world restore tests. Confirm old-world
25 kg roundtrip and new-world 32 kg conservation independently.

No Godot run is currently authorized. After implementation review request an
exact-head exclusive no-port lease using AST-extracted functions from the
versioned tools/ci/run-godot-checks.ps1, not the full runner/import/startup path.
Proposed initial set: a new finite_bootstrap_acquisition_test.gd plus existing
player_extraction_loopback_test.gd and scratch_construction_runtime_test.gd;
add only affected restore/schema companion checks after source review. Propose
30 seconds per test, 120 seconds aggregate, no listeners/import/capture/export;
Coordinator must grant exact commands/head/bounds before execution. Stop at the
first failure or diagnostic, preserve logs, release with a fresh process query,
and do not edit/retry during the lease. CI must run all actual required Windows/
Linux main and companion checks at the immutable final head, with artifact
provenance verified by Coordinator. Screenshots only if tests leave material
uncertainty. PR85, merges, deployment, publication and successor dispatch stay
outside worker scope.
