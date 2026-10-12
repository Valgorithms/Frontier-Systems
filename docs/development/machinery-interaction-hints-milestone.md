# Machinery interaction hints milestone

The existing card now explains the currently bound mouse selection and cursor controls. Selecting a machine opens Construction for that exact observed assembly without submitting a machine intent. Keyboard/controller bindings truthfully state the existing static-body picking limit and direct the player to Construction's chooser; unbound selection retains that route. Unbound cursor controls describe release-camera or Controls settings routes.

Hints occupy a wrapping fifth row in the existing anchored card; no persistent world labels or new shortcuts are added. The hint is hidden while Construction is visible or GUI/settings owns input. Observed identity, energy, job details and fresh/stale/blocked/paused/outcome-unknown copy remain independent of the hint. The card fits its content height within the scene. Bindings are read live without preference writes.

## Ownership and contracts

MachineryPreview and MachineryContextCard own only local presentation and per-frame hint refresh. Canonical production state remains in ProductionSimulationSystem and persisted records. Tick cadence, schemas, authenticated command validation/transport, pending identities, receipts, persistence, paid resource accounting and collision/mesh construction are unchanged. Existing bounded activity telemetry remains the profiling signal; no new simulation work occurs.

Scope is machinery_context_card.gd, machinery_preview.gd, the existing focused machinery_context_shell_test.gd and this document. Inventory hints PR125, walker PR124, shared bootstrap/input/camera and authority boundaries are outside scope.

## Verification

Godot 4.7.2 on Windows: repository runner import and startup checks, paid no-port actual-client-shell regression and machinery_preview_test pass. The shell uses authenticated real-domain commands to acquire/assemble machines and exercise running, timeout-stale, host-blocked, saved/restored paused and outcome-unknown states. It injects mouse motion/button input through the actual root window and confirms exact-machine Construction selection and zero outbound machine intents. It covers hover/exit/reset/disconnect, GUI focus and suspended input, drawer/tab transitions, live in-memory mouse/keyboard/controller/unbound bindings, canonical snapshot and collider identity/transform/bounds invariance. Narrow widths include 640, 480 and 360 px with full wrapped hint and uncertainty line bounds.

Adjacent machinery_activity_animation_test and integrated_panel_layout_test regressions pass. Windows/Linux PR CI execution and exact tested synthetic merge SHA are pending; the documentation-only initial draft CI is not runtime evidence.

## Limitations

Keyboard/controller world selection currently routes only Area3D; machinery uses StaticBody3D. This PR describes the existing Construction chooser route and does not repair shared picking. Input/cursor descriptions are tested through bindings and injected mouse events; headless checks do not establish native capture, physical controller/VR or human gameplay acceptance. Screenshots are unnecessary where meaningful runtime/layout tests and source review establish this presentation change; no media, ports, releases or deployment are used. This task does not self-merge. Worktree remains active for coordinator review.
