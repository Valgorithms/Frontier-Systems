# Paid panel collision descriptor boundary

The next physical panel lifecycle requires complete server-owned geometry.
`HorizontalPanelPreview` consumes an own-builder projection and uses picking
Areas, so it cannot be promoted into a complete physical world. The local
character is a presentation-only 1800 mm capsule with radius 300 mm, environment
mask 1 and body layer 2. Its pose is not authoritative Inventory state.

Proposed scope: a synchronous Production API derives bounded, deterministic
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

Owner API, schema, lifecycle tests and OS CI are pending coordinator scope
acceptance. No scene wiring or physical-contact behavior is claimed here.
Future wiring must invalidate retained bodies on scope change, disconnect,
staleness, removal, restore and teardown, and demonstrate actual
PhysicsServer3D/CharacterBody3D contact and removal. A descriptor result alone
cannot supply that evidence or revoke a previously retained client copy.

Existing fixture floors, wall collision, picking and movement policy remain
outside this boundary. This work establishes no pressure, airtightness,
falling, load-bearing, capture, public media or deployment behavior.
