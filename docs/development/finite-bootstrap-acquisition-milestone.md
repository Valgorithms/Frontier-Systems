# Finite default-start enclosure acquisition

Base: `5d57ed7d68c73018d2df42e069ebab85fc8af59c` (PR144 implementation merge
`4e6b463fdd4d769c5c48c41bcfe3d735fde4eb34`).
Owner: worker `01a16a3c-873a-7be2-987a-768ddd5d6a42`.
Coordinator `01a1283c-45d6-7e61-bedd-905e8797f03d` owns design acceptance,
leases and merges. Status: scoped implementation authorized after design and
full-budget review; local Godot execution awaits an exact-head lease.

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
| Remaining material | deficit 3.8 kg | 0.2 kg iron + 0.2 kg plate |

The algebraic deficit requires 6.333334 kg additional ore, but the existing 1 kg
recipe consumes whole batches; seven additional batches are the smallest usable
increment. Existing new-world Production matter is 25 kg; a distinct 7 kg seam
would make that budget 32 kg. Terrain's separate 2 kg is unchanged. This is an
explicit increase in finite world-resource commissioning.
The Coordinator explicitly authorized this narrow commissioning increase.
No alternate recipe, replenishment, free depot credit or salvage relabeling is
proposed. Crafting eight 1 kg plates for a 7.6 kg plate bill can leave 0.4 kg plate
before the 0.2 kg plate seal debit; final residuals are 0.2 kg plate and 0.2 kg iron.

## Accepted acquisition slice

Prefer a separately identified finite iron-ore outcrop using the existing
Production acquisition/carrier/refinery transaction paths. Do not extend the
homogeneous dirt owner into an ore converter or introduce a Terrain-to-Production
mass bridge merely to fund this room. Production already owns ore sources and
all downstream conserved stock. Inventory continues to own physical carriers,
body/reach/hand authorization; Tools owns active extractor capability and wear.
Keep acquisition at fixed-tick command ingress and Production at priority 300;
use its existing bounded counters, exact-intent receipts and capacity claims.

The accepted content adds `deposit.iron.outcrop`, a separately selectable finite
7 kg source co-located at the existing iron reach anchor `[-3000, 0, -1000]`
(millimetres). This prototype shares the existing site presentation; it is not a
new terrain generator or artwork. Catalog v1 remains immutable. Catalog v2 adds
only this source, retaining every recipe/yield/bill.

Production persistence v12/catalog revision2 identifies a new 32 kg origin and
requires exactly four deposit keys, their bounded initial amounts, the exact v2
catalog fingerprint and total conservation. Historical versions1–11 require
catalog revision1, exact v1 fingerprint, three original keys and 25 kg total;
they normalize to v11 with the outcrop absent (semantic zero). Missing historical
Production also commissions only the original 25 kg. Recovery never converts an
old origin into a new grant. Unknown versions, fingerprints, missing/extra source
keys and refill inflation reject atomically. Observation v14/catalog2 exposes the
new source; historical worlds retain v13/catalog1.

`FirstPlayableBootstrap.create_playable_world()` is the shared host/local-app
composition factory. It enables the existing starter carrier inventory and the
explicit fresh-world outcrop flag before attachment initializes owners. Bare
WorldRuntime defaults remain historical for existing fixtures/recovery. The test
uses the actual factory without invoking host networking.

Bound scope: Production source/catalog/save validation, existing source selector
observation/UI allowlists, focused integration/schema tests, architecture and
this milestone contract. No pressure/access geometry changes, new owner, service,
asset, dependency, environment variable or terrain material conversion.

## Acceptance and proposed bounded checks

Positive: pristine new-world initialization only; acquire through real source
commands into an owned canister; unload and refine 17 complete batches with
unchanged yields and paid energy; build the established paid enclosure/crowbar/
seal via current commands; retain all tails, leftovers, energy and source
balances. Commission the supported room through the existing authenticated path.
No direct owner snapshot seed or store edit in the positive acceptance flow.

New route controls cover exhausted source, absent active tool, foreign carrier,
stale revision, out of reach, drill power, exact replay and changed-payload retry.
Separate, validated negative-only world fixtures cover full-carrier and
insufficient-energy rejection; those fixtures never fund the positive route.
Each failure leaves material owners unchanged. Save/reload partly depleted and
exhausted sources into fresh pre-start worlds (the runner deliberately forbids
live restore), then resume the positive route; reject injected origin budgets, unknown
catalog/version, duplicate source mass, forged receipts and legacy grant attempts.
Keep reservation-spend guards and whole-world restore tests. Confirm old-world
25 kg roundtrip and new-world 32 kg conservation independently.

No Godot run is currently authorized. After implementation review request an
exact-head exclusive no-port lease using AST-extracted functions from the
versioned tools/ci/run-godot-checks.ps1, not the full runner/import/startup path.
Proposed initial set: a new finite_bootstrap_acquisition_test.gd plus existing
scratch_construction_runtime_test.gd; the listener-based player extraction
loopback belongs in CI or a separately authorized listener lease;
add only affected restore/schema companion checks after source review. Propose
30 seconds per test, 120 seconds aggregate, no listeners/import/capture/export;
Coordinator must grant exact commands/head/bounds before execution. Stop at the
first failure or diagnostic, preserve logs, release with a fresh process query,
and do not edit/retry during the lease. CI must run all actual required Windows/
Linux main and companion checks at the immutable final head, with artifact
provenance verified by Coordinator. Screenshots only if tests leave material
uncertainty. PR85, merges, deployment, publication and successor dispatch stay
outside worker scope.

## Coordinator-reviewed commissioning and bootstrap budget follow-up

Coordinator approved the distinct depletable 7 kg new-world source and this
complete budget, with historical seam mass zero and no other grants. This supersedes only the resource-content
restriction for that source, not the runtime lease requirement.

The real first-playable bootstrap sets `resource_carriers_enabled = true`
(src/app/first_playable_bootstrap.gd:56); WorldRuntime forwards that flag to
Inventory configure_defaults (src/core/runtime/world_runtime.gd:42). The loaded
shared.production.v1.json already gives body.human-2 resource-canister-1 and an
extractor-1 inside its accessible backpack; body.human-1 can collect canister-2
from world.tray-1 and equip extractor-2 from its backpack. All four items start
at condition 1000/1000. Use existing inventory equip/transfer commands and an
unreserved spare hand. No new carrier/extractor fabrication or salvage credit is
required. These are explicitly supplied prototype tools, not Production mass.
Inventory active_tool checks the active hand and Tool capability provider;
owned_resource_carriers checks identity and contents access. The integrated
player_extraction_loopback_test.gd already exercises real equip of extractor-2.
The positive new test must retain these real initialization paths and controls.

Use 17 `tool_extract` operations of exactly 1 kg each, unloading the existing
canister after every extraction before the next source trip. Extraction costs
ceil(amount/4000) = 250 J per kg (Production _plan), requires drill power and
source reach, and invokes Tools prepare_usage once per successful operation.
Tool bindings v2 use space iron: wear 1 ppm/cycle, head scale1000, drive250,
frame0. After17cycles head integrity999983, drive999996 with remainder250,
frame1000000; all remain above50000. Repair and replacement cost zero for this
route because neither is required. There is no separate tool battery debit;
Production energy is the existing powered extraction abstraction.

| Step | Count and debit | Energy |
| --- | --- | ---: |
| Extract ore into starter canister | 17 x 1 kg; finite source debit | 4250 J |
| Unload cargo | 17 owned transfers | 0 J |
| Refine iron | 17 x 1 kg ore ->10.2 kg iron +6.8 kg tailings | 17000 J |
| Craft plate | 8 x 1 kg iron ->8 kg plate | 8000 J |
| Fabricate crowbar | equipment.crowbar, 2 kg iron | 2000 J |
| Place enclosure | 7.6 kg plate including paid door | 0 J |
| Install seal | 0.2 kg plate | 0 J |
| Commission room | existing paid/held-tool checks | 0 J |
| Total | 17 kg acquired ore | 31250 J |

Source: catalog.v1.json recipe energy; equipment-blueprints.v1.json crowbar;
Production _prepare_fabrication and _plan; PaidDoorSeal and paid wall/panel/door
planners have no energy debit. All fixture station power flags initially true;
Production initial_record starts100000J. Final energy68750J, without generation
or refills. Canonical final acquired mass:7.8kg installed plate (7.6 enclosure +
0.2 seal),2kg crowbar iron,0.2kg leftover plate,0.2kg leftover iron,6.8kg tails
=17kg. Existing5kgice+10kgregolith remain untouched, total32kg. At most17kg
passes through the100kg depot, one1kg extraction occupies the2kg carrier, and
there is one active batch. Empty the carrier between trips. Hand assembly could
reduce crowbar energy but is unnecessary for this conservative valid route.

Correction to the initial proposal: the seal consumes plate, not raw iron.
The total9.8kg bill and17kgore minimum are unchanged. Residuals are specifically
0.2kgplate plus0.2kgiron, not0.4kgplate. The full material and energy budget fits
with already usable starter gear; no additional ore above the reviewed7kg is
needed. These are source-backed calculations, pending runtime acceptance.


## Restore representation verification

The diagnostic partial checkpoint at tick1264 changed no JSON values. Inventory
restore normalized40 integer-contract fields from lexical `N.0` to `N`: owner and
ledger schema versions, six container capacity triplets, eight item condition /
definition revisions, and body profile/schema/state revisions. Exact candidate,
restored and recursive-diff records are preserved in local CI evidence. No
Production, Tools, receipt, tick, construction or physical body value changed.

The regression compares parsed JSON recursively with exact types and values,
exact object-key sets and ordered arrays; it uses no numeric tolerance or string /
boolean coercion. JSON numbers are a single type, so equivalent `N` / `N.0`
spellings normalize through the parser. Dedicated negative controls mutate source,
energy, receipt, tool, body, tick, missing/extra fields and receipt array order. Raw
candidate/restored records remain emitted for diagnosis.
