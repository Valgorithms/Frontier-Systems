# Machine activity animation

Observation-only engineering animation. PR108 owns machine mesh presentation until
merged; PR109 owns camera/input. Initial work adds an independent helper and tests.

Motion requires increasing host-observed job progress for the same recipe across
increasing ticks. Paused, blocked, replaced, stale, missing and disconnected records
freeze motion. Job disappearance cannot distinguish completion from cancellation;
show an unknown outcome, never a fabricated completion. No simulation/persistence,
material, UI/bootstrap, camera, schema or network contract changes are in scope.

Animation phase is cosmetic, bounded and finite; wall-clock timeout only expires
visual evidence and never advances a job. First-party procedural transforms are MIT;
no imported art or generative imagery. No videos, public uploads or deployment.

Verification and final revision will be recorded after integration against merged
PR108, focused paid runtime tests and required Windows/Linux CI.

Helper-stage verification: pinned Godot 4.7.2 Windows import, startup and the paid
no-port machinery_activity_animation_test pass. Tests cover finite extraction,
actual restored pause, isolation, disconnect/reconnect, actual completion versus
cancellation ambiguity, stale/malformed/duplicate/replaced/regressed observations,
expiration, finite/bounded/frame-partitioned phase and full canonical snapshot
invariance. Cosmetic extractor/refinery drive geometry has no collision objects;
100 sampled rotations remain within unchanged machine envelopes. An initial test
used an impossible static type assertion; it was corrected and the focused runner
passed. This stage has no integrated presentation or graphical acceptance claim.

Only extractor/refinery have sustained machine job telemetry. Instantaneous
printer/autolathe operations and power generation do not earn fabricated cycles.
Completion signals exist within the host but are absent from this scoped wire
record; the helper intentionally has no completed-state transition. Phase has no
relationship to progress/yield. Job identity is limited to recipe and observed
progress, because telemetry supplies no stable job ID; replacement/regression or
record loss clears continuation evidence. A same-recipe unseen replacement cannot
be distinguished by this existing contract.

First-party drive vane/pump rotor/indicator source: machinery_activity_parts.gd;
original primitive geometry authored for Frontier Systems, MIT. Creation tools:
text editing and ordinary Godot 4.7.2 rendering. No external artwork or assets.
