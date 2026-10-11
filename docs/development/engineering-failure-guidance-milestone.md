# Engineering request failure guidance milestone

Scope: Workstation (`LocalProductionPanel`), Inventory (`PlayerInventoryPanel`), and Construction (`MachineryPanel`) receipt presentation only.

Audit: these panels preserve rejection messages but mostly omit the code and a next step. Production uses `production_rejected` for multiple reasons; inventory uses `inventory_development_rejected` and `shared_inventory_conflict`; wall validation uses `wall_construction_denied`. These broad codes must not be interpreted as a specific stale, resource, capacity or reach diagnosis. Specific inventory revision/source and equipment slot capacity codes can receive specific advice. Unknown codes receive no guessed recovery advice.

Acceptance: retain original code/message and wall-removal uncertainty; add only code-selected advisory text. A fresh observation is a review opportunity, not proof that an action succeeded or can succeed. The next action remains explicit. No retry, replay, pose-derived permission, schema, canonical state, epoch or reconnect changes. Existing tutorial human acceptance remains unverified.

Verification pending: focused actual-panel fixtures, existing bounded Godot runner, and exact-head Windows/Linux CI. No sockets/ports, live services, media upload, release, deployment or merge.
