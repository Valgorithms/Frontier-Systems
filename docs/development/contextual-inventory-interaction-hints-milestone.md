# Contextual inventory interaction hints

Presentation-only follow-up to PR122 (89ef6df247c7a4825a23595ed79c471ff42469b3).

Scope: the existing hovered/selected world-item card in InventorySelectionLabel and ProceduralWorldInventoryPreview, focused real-shell regression coverage, and this milestone record. Controls help already documents selection/collection; no additional persistent instruction card is needed.

Acceptance: opt-in captions remain quiet by default; hovered/selected context explains existing selection/pickup inputs, clears on reset/disconnect, remains bounded in a narrow shell, and preserves neutral unknown role, exact observed details, paid inventory records, geometry, stable request identity and pending/outcome uncertainty.

Verification pending. No simulation, schemas, transports, shared input/bootstrap/camera, machinery captions or walker changes. No self-merge, video, uploads, release or deployment.

## Implementation and local evidence

One fourth, wrapping row in the existing contextual card explains the configured world-selection binding. Mouse hover describes select and double-click request; selection describes double-click pickup request. Keyboard/controller bindings describe select-and-request; an unbound route points to Controls. The caption makes no eligibility or success claim and unknown definitions retain the neutral Item role. The existing observed details still expose exact identity and contents uncertainty.

Godot 4.7.2, Windows: bounded runner import/startup and world_inventory_context_labels_test.gd, world_inventory_preview_test.gd, selected_target_controls_test.gd passed. The actual-shell fixture uses eight real items including four paid builds, opens no ports and saves nothing. It checks default-off captions, hover/selection, remaps/unbound input, reset/rebuild/disconnect, 640px and 1440px shells, unchanged meshes/colliders and canonical snapshot, exact pickup identity, and pending/disconnect uncertainty. Headless hover uses the native Area3D signal after a genuine camera ray assertion; mouse selection is injected through the shell.

No internal stills were needed: source and layout/runtime assertions establish the scoped behavior. Human/controller hardware/VR and Linux graphical acceptance were not exercised; this is no claim of those acceptance paths. Required Windows/Linux CI and exact tested synthetic SHA will be recorded in the handoff after completion.
