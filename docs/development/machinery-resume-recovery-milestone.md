# Machinery paused-batch recovery milestone

Successor to PR #93 (`380c22878937bbde17f96a1c6f8355913814154e`). Tests and documentation only. Exercise the actual client MachineryPanel with authenticated loopback transport, native temporary checkpoints, replacement host and explicit manual reconnect. Preserve paid finite canister inputs, outputs, provenance and job energy.

Source review identifies a runtime limitation: `machine_resume` clears the pause flag after checking job existence and access; recipe prerequisites are checked during progress, so missing inputs/modules/power stall rather than reject Resume. Deployed frames are shared within authenticated reach; foreign owned packed frames are rejected. Resume carries machine ID and production revision; recipe is the canonical saved job, not a client-selected replacement recipe.

Verification pending. Synthetic controls and in-process replacement do not establish human gameplay or abrupt-crash durability. No public media, deployment or merge by this chat.
