# Paid panel collision descriptor boundary

The next physical panel lifecycle requires complete server-owned geometry.
`HorizontalPanelPreview` consumes an own-builder projection and uses picking
Areas, so it cannot be promoted into a complete physical world. The local
character is a presentation-only 1800 mm capsule with radius 300 mm, environment
mask 1 and body layer 2. Its pose is not authoritative Inventory state.

Accepted scope: a synchronous Production API derives bounded, deterministic
floor and ceiling box descriptions from the validated current paid panel
registry. Inventory validates the authenticated human and world/region scope.
Production remains the sole panel owner. No additional canonical registry,
network endpoint, retained collision objects or movement permission is added.

Geometry is in station integer millimetres. Floors have their upper face at
0 mm, ceilings their lower face at 2000 mm, with 12 mm thickness extending
outward. The preview currently centers its 12 mm mesh on those planes; scene
wiring must reconcile that discrepancy explicitly. The preview display uses
`DISPLAY_ORIGIN = (-6, 0, 2)` metres; station-to-display mapping is translation
plus division by 1000, with identity axes and no scaling or rotation. A future
consumer must validate its own parent transform rather than assuming local
coordinates are global physics coordinates.

`ProductionSimulationSystem.paid_panel_collision_descriptors(context,
expected_revision)` validates the current human/scope through Inventory and
requires a strict bounded integer matching the current Production revision.
It revalidates the complete paid registry (bills, dimensions, bounds, grid,
overlaps and capacity) through `PaidPanelCollisionDescriptors`, then returns
boxes sorted by stable surface ID. The v1 result schema records world, region,
station coordinate frame, Production revision/tick, Inventory tick and an
inspected-panel count. The paid 50 mm grid makes half dimensions/centers integral;
no geometry rounding or approximation is needed. Work is bounded to 64 panels
and the existing paid registry validator's bounded pairwise overlap scan.

This server-internal API intentionally includes foreign stable surface IDs to
describe the complete collision input. Principal IDs, materials and session
details are excluded. The own-only public projection is unchanged, and no
network command, observation field or client-provided geometry input exposes
the new API. Pure helper results establish geometry only, not provenance.

Reads do not yield, mutate, persist or cache; Production still owns all panels
and Inventory all bodies. No new tick system or save version is introduced.
Invalid records, absent/detached owners, invalid context/scope, unsupported body
profiles and stale revisions return a denial with no partial geometry. The
same existing human-profile mapping as paid-floor support gates this boundary.

Results are transient detached data, never reusable authority. A removal is
visible on the next synchronous read. A restore can repeat the same revision
with different geometry: revision equality does not make an old result valid.
The API validates static context/grants; actual session revocation belongs to
ingress. It cannot detect a disconnected session from a still-valid context
object, or destroy objects retained by a future consumer. Such a consumer must
obtain current authenticated context and rederive from the current owners;
retained use needs explicit restore-generation and lifecycle invalidation.

No scene wiring or physical-contact behavior is claimed here.
Future wiring must invalidate retained bodies on scope change, disconnect,
staleness, removal, restore and teardown, and demonstrate actual
PhysicsServer3D/CharacterBody3D contact and removal. A descriptor result alone
cannot supply that evidence or revoke a previously retained client copy.

Existing fixture floors, wall collision, picking and movement policy remain
outside this boundary. This work establishes no pressure, airtightness,
falling, load-bearing, capture, public media or deployment behavior.

Implementation base: merged PR138 `8b8c05bca7d0890258930fbef48e08c19f37a767`.
The coordinator's later ledger-only `de3ef2c` is not this branch's base.
The real-owner Godot regression emits JSON for strict schema checks and covers
paid build/removal, two builders versus own-only observation, detached output,
stale/type/scope/grant negatives, detached owner, whole-world restore and an
equal-revision/equal-bill restore with changed dimensions. The pure helper also
rejects bad bills/grid/capacity and tests bounded negative coordinate centers.
The existing recipe workflow runs the regression and emitted schema checks
on both Windows and Linux; exact test/CI evidence is recorded in the PR.
