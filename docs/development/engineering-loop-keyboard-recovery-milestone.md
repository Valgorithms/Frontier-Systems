# Engineering loop keyboard and recovery milestone

Successor to unloading PR69, based on integration revision `d3fbbad`. The current shell now gives the recipe picker keyboard focus when navigating to the workstation. Manual checkpoint feedback supports keyboard focus and reveals its wrapped pending/result text after layout settles without taking focus from another control. Save correlation, disconnect uncertainty and observation-only behavior retain their existing contracts.

ProductionSimulationSystem and InventorySimulationSystem own canonical matter, identities, access and tick execution. WorldPersistenceAdapter and LocalWorldSaveStore retain the checkpoint contract. This change is presentation and verification only; it changes no canonical owner, cadence, schema, command validation, network/controller rule, profiling signal or runtime configuration. First-party code and documentation remain MIT; no art, third-party assets or AI imagery is added.

## Pinned review route

At 1920 x 1080, use the current Workstation tab's Gather / carry section. Select `deposit.iron`, `resource-canister-1` and 1000 g at source reach. Focus Extract and press Enter. Return to workstation reach, select `ore.iron`, then focus Unload and press Enter. Inspect the exact host command ID, carrier/material/mass and scoped receiving store. Navigate to Refine / collect / recycle; workstation navigation should focus the recipe picker. Run two `refine.iron` batches, waiting for fresh completed observations, then `craft.plate`, collect the physical plate and recycle that exact stable plate ID. Repeat the loop with a new physical identity.

The automated current catalog yields 600000 mg iron and 400000 mg tailings per 1000000 mg ore batch. After two complete two-batch loops and physical recycling: source 6000000 mg, iron 2400000 mg, tailings 1600000 mg, empty ore stock/canister and no surviving plate. All 10000000 mg remain accounted for. Recipe acknowledgement reserves work; it does not establish batch completion.

Request Save shared world now and inspect the matching disk result without manually scrolling to it. Focus checkpoint feedback with the keyboard. Submit a further save, disconnect before acknowledgement, then inspect fresh restored state. The abandoned request remains unknown; a late receipt or new observation cannot claim it saved or replay it. Explicit retry is a new user action.

## Verification and limits

`engineering_loop_shell_test.gd` reuses the actual integrated client shell, injects GUI Enter keys and delegates paid actions to the real domain owners. It writes/reads a real checkpoint in a unique temporary user directory, replaces the canonical world, delivers fresh observations and checks retained extraction replay without resource duplication. The socket-free adapter explicitly delivers receipts; the save result follows a synchronous test-only disk write, not the production worker/network transport. Existing cooperative and checkpoint suites cover that boundary separately. Position changes use authoritative fixture movement commands; no character-driven movement or human input is asserted.

The focused checkpoint and reconnect navigation regressions verify automatic result visibility and keyboard focus without manual result-scroll assistance. Versioned bounded Windows runner commands, exact head and actual results are reported in the PR handoff. Logs/JUnit remain ignored under `var/ci/engineering-loop-*`. No ports are needed for the combined shell fixture.

Coordinator must arrange a fresh-profile human keyboard/mouse run on the reviewed integrated head, including movement/look/cursor handoff, target selection, the repeatable finite engineering loop and save/reconnect through the actual client. Automated fixtures cannot satisfy that gate. Tutorial readiness remains **not established**; no tutorial recording, controller/VR, Linux graphical, packaged build, live external service, game release, deployment or media upload is claimed. Any future native capture must remain internal and record its exact head, renderer, viewport and ordinary engine provenance. The worktree stays attached while the draft PR is under review.
