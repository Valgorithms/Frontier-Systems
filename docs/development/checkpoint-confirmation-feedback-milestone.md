# Checkpoint confirmation feedback

The source-playable save button gets a separate, wrapped session-only status. The most recent explicit request owns that status by its exact command reference; only its completion confirms disk success. Observations and unrelated completions cannot replace it. A new explicit save replaces the prior status. Disconnect invalidates correlation; an unresolved request reports an unknown outcome and is never replayed.

No world state, save implementation, wire schema, persistence format or authority changes. This slice is separate from general error guidance and restore fencing.

Verification pending: socket-free actual-shell receipt/observation ordering, unrelated and stale completions, new saves, queue failure and disconnect; exact-head Windows/Linux CI. Prior PR53 network evidence remains scoped to PR53. No ports, native graphical run, public media, deployment or merge.
