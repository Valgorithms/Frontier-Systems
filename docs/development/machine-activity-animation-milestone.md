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

This change targets extractor/refinery sustained jobs. Printer/autolathe and power
generation keep their existing presentation. Instantaneous print/make operations
do not earn fabricated cycles; printer recipes can also use sustained machine_run,
but expanding printer presentation is outside this narrow milestone.
Completion signals exist within the host but are absent from this scoped wire
record; the helper intentionally has no completed-state transition. Phase has no
relationship to progress/yield. Job identity is limited to recipe and observed
progress, because telemetry supplies no stable job ID; replacement/regression or
record loss clears continuation evidence. A same-recipe unseen replacement cannot
be distinguished by this existing contract.

First-party drive vane/pump rotor/indicator source: machinery_activity_parts.gd;
original primitive geometry authored for Frontier Systems, MIT. Creation tools:
text editing and ordinary Godot 4.7.2 rendering. No external artwork or assets.

Integrated after verified PR108 merge a482de1637e2219c26173428678113eb45559f03.
The existing machinery preview owns cosmetic parts and updates them per render
frame; the helper owns detached state/phase. Layout rebuilds release old handles;
the existing disconnect path removes all meshes and labels. Activity captions and
neutral/teal/amber/purple indicators distinguish idle, observed progress,
paused/blocked, and unknown/ended-unconfirmed evidence. Collisions, selection,
camera/input, bootstrap, UI panels, wire schemas and canonical systems are unchanged.
Motion is a repeating cosmetic drive cycle, never a percentage, yield or countdown.
Evidence expires after one second without a strictly newer host tick; duplicate
observations do not renew it. Delta is finite/positive and motion is clamped to
0.1 seconds/frame; long gaps expire evidence before moving. No phase is persisted.

Local integrated Windows 4.7.2 verification: import/startup plus activity,
engineering_object_details, machinery_operation_feedback and machinery_preview
tests: six checks, zero failures. Paid actual preview exercises drive motion,
timeout, isolation, real restored pause and disconnect mesh cleanup; original
collision identities and full canonical snapshot remain unchanged.

Native evidence: run tools/ci/capture-machinery-activity.ps1 in an isolated clean
checkout. It uses the paid domain fixture, real compact client shell and an injected
remote adapter with no sockets, temporary input profile, OpenGL compatibility
renderer and a bounded process. Local ignored var/captures/machinery-activity has
unedited running-a/running-b, paused, unknown, refinery-running and disconnected
PNGs plus log/source/hash manifest. Visual review confirms visible drive phases,
readable activity caveats and amber/purple/teal indicators. The refinery uses already
paid extracted ice and a newly crafted/wired cable; no resource grants. Initial
captures exposed a viewport resize delay and exhausted iron/reach fixture setup;
the capture tool now waits for viewport readiness and uses valid paid ice commands.
No production changes were made to accommodate the fixture. Human/controller/VR,
Linux graphical, live remote-network and hardware acceptance remain unverified.
