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
