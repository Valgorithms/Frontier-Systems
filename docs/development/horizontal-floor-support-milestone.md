# Detached paid floor support queries

Production owns paid horizontal panel records and their revision. This foundation
owns no canonical state: a trusted future fixed-tick adapter supplies the complete
descriptor set from validated HorizontalPanelConstruction records and the current
Production revision. A descriptor is geometry, not proof of payment or authority;
UI observations, can_operate and client-supplied geometry cannot authorize movement.

HorizontalFloorSupportQuery will validate a versioned request, exact expected
revision, and at most 64 unique, nonoverlapping paid-panel-shaped descriptors.
Coordinates use the existing station frame: X/Z horizontal, +Y up, integer
millimetres. Bounds are [xmin,xmax,zmin,zmax] within +/-100500 mm.
The actor footprint is a positive axis-aligned rectangle, at most 2000 mm per
axis, with foot height in the same frame. Vertical tolerance is 0..100 mm;
support requires floor_y <= foot_y <= floor_y + tolerance. Floors are at Y=0;
ceilings at Y=2000 never support walking. No coordinate transform is implicit.

The entire footprint must be covered by the union of eligible floors. Shared
edges count as closed boundaries; edge-only contact has no positive-area support.
An integer strip/interval sweep will detect internal gaps, including gaps missed
by corner sampling. Duplicate IDs, positive-area same-kind overlaps, invalid
numbers/grid/extents and stale revisions fail closed. Valid absence/removal yields
unsupported. Sorted surface IDs make results independent of descriptor order.

Queries run on demand, with no ticks, side effects, retained cache or persistence.
Inputs and canonical records remain unchanged; restored equivalent descriptors
produce equivalent results. Bounded per-query counts expose inspected surfaces,
candidate floors and sweep strips without changing behavior. Failure returns a
ServiceResult denial rather than a partial support grant.

Next boundary: the authoritative movement adapter must obtain complete current
Production descriptors, derive actor footprint/foot height from canonical body
state, match revisions at its commit tick, and combine this result with existing
gravity, collision, capability and reservation policies. This change does not
wire that adapter, change movement or saves, or establish collision, load bearing,
airtightness, pressure, graphics, controller/VR or deployment behavior.

Verification and exact source/CI tested revisions are recorded in the PR.
