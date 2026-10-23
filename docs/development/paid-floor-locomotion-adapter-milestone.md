# Paid floor locomotion adapter

Owner: Production for installed paid panels, Inventory for authenticated body pose.
Base: PR137 merge `1a7bfb328245a8b5ae82251defe1e7d79761ee71`.

Proposed bounded outcome: an authenticated synchronous assessment uses complete current Production panels and the current Inventory body pose to derive horizontal floor contact, then feeds the existing locomotion environment policy. No retained contact, duplicate floor registry, client contact, UI projection, or caller position supplies authority.

The human body support profile explicitly interprets the logical position as a capsule-center anchor: 1800 mm height, 600 mm diameter, feet 900 mm below the center. A conservative 600 mm square footprint must be fully covered. This matches the optional local walker bridge's coordinate convention. Legacy logical fixtures at Y=0 are not silently treated as feet at Y=0. This profile is a bounded assessment contract, not physical collision or a migration of saved positions.

Acceptance: actual owner tests create finite paid panels and assess interior, adjacency, gaps, overhang, ceiling exclusion, removal and restore. Foreign identities and forged support fields reject. Repeated calls read current owners. Gravity, equipment, reservations, fixture movement and constructed-wall motion checks remain governed by existing owners. No falling, floor-only movement enforcement, UI behavior, or physical collision is claimed.

Existing owner edits require coordinator scope acceptance. Local Godot requires a separate explicit no-port lease after process inspection. Windows and Linux CI must pass at the final PR head. Coordinator owns approval and merge; no deployment or publication is in scope.
