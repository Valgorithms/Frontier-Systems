# FP-01 controller lifecycle invalidation

Serialized successor to PR #55 (`ec7c9dc8c8aad0165c78897239d0a6ef37ed2705`). Scope: canonical successful control epoch transitions invalidate scoped inventory work and grip participation atomically, preserving physical inventory and unrelated bodies. Production admission, network composition, receipt/high-water changes, schemas, startup migration, UI and media remain deferred.

Implementation and verification evidence will be recorded before handoff. No merge or deployment is authorized; retain this worktree for Coordinator review.
