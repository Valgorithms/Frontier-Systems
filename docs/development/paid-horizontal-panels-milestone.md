# Canonical paid horizontal panels

Production owns up to 64 horizontal panel records. This first integration adds
fixed-tick authenticated `panel_build` / `panel_remove` owner commands and an
on-demand `construction_closure` query. No player UI or new network operation is
introduced. Observation v9 remains unchanged; the registry is private to the
owner and persistent snapshot. This is geometric closure, not airtightness,
load-bearing floors, collision, pressure, gravity or deployed gameplay.

Build takes exactly `expected_revision`, `kind`, `bounds_millimetres` (X min/max,
Z min/max), and `height_millimetres`. Each extent is 50..1000 mm, on the 50 mm
grid, coordinates within +/-100500 mm. Floor Y is 0 and ceiling Y is 2000.
The installation floor anchor must be reachable through existing Inventory
capabilities. Positive-area same-plane overlap is denied. Removal takes exactly
`expected_revision` and `panel_id` and requires the creating principal.

Blueprint `surface.horizontal-panel` revision 1 consumes 1 mg of canonical
Production `store.plate` per square millimetre (1 kg/m2). The existing printer
recipe consumes 1,000,000 mg refined iron and outputs 1,000,000 mg plate in
120 ticks for 1000 J. This command cuts installed boundary sheets directly from
that finite processed stock; it does not mint physical Inventory plates.
Every record retains the exact rectangle, plane, principal, blueprint/revision
and area-derived plate bill. Removal refunds that exact plate mass once,
subject to store plus reserved output capacity. IDs hash principal and request;
existing principal-bound receipts provide exact-intent retries and reject ID
reuse. Shared canister claim coverage still runs before every commit.

Save version 9 requires the panel registry, checks all shapes, dimensions,
overlaps, pinned bills and whole-world conservation. Versions 1..8 migrate to
an empty registry. Version 8 files remain supported; old schemas are retained.
No async callback or UI mutates this state. Work occurs only on command ticks;
closure is derived on demand from walls and panels at the same owner revision.
Profiling adds panel count and total installed panel mass. Existing command
failures expose denial; no new configuration, assets or dependencies are used.

Acceptance uses ten finite ore batches, yielding 6 kg iron and 4 kg tailings,
then six real plate recipes. Four paid walls enclose 800x1000 mm; floor and
ceiling cost 0.8 kg each, leaving 0.4 kg plate stock. The previous six-wall
1800x1000 mm perimeter remains a separate regression. General 900x1000 mm
dimensions are also checked, without granting extra fixture resources.

Verification results and exact tested head are recorded in the PR. Graphical,
controller/VR, live network and deployment acceptance are outside this scope.
