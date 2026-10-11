# Inventory tray handoffs and owned storage milestone

Scope: PlayerInventoryPanel, a disposable presentation helper, and focused tests. No simulation, networking, schemas, persistence, world preview, input targeting, production equipment or terrain changes.

Base: origin/dev-master at 0922ed44498af3eca2bd815e54628756e475be17.

Acceptance: preserve item/container/hand IDs through reordered observations; clear vanished selections; distinguish all owned descendants from direct nearby tray contents; pin pending pickup/drop/owned-transfer targets; explain locally known prerequisites and host-only uncertainty; report rejection/disconnect without inferring success from disappearance.

Verification results will be recorded after implementation. Existing Windows/Linux CI discovers headless tests. Graphical and live multiplayer acceptance require separate evidence. No ports, art assets or media uploads are needed.
