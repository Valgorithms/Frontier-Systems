# Observed crew locomotion pose

Remote crew capsules become original primitive torso/head/limb geometry. ObservedAvatarPresentation is disposable MIT presentation only: host inventory retains canonical body identity, position, tick ownership and persistence. Existing crew slot keys, self exclusion, display origin/height, parent, removal and disconnect cleanup remain unchanged; no colliders, picking proxies, commands or schemas are added.

Coordinator approved the sole shared-file boundary: FirstPlayableBootstrap avatar construction and its observed-position assignment. Camera/input, UI and all other bootstrap logic are excluded.

Pose advances only on fresh increasing-tick horizontal observed displacement. First samples, stationary/vertical movement, jumps/corrections over one metre and first samples after 0.5 seconds stale neutralize limbs. Duplicate/regressing/malformed samples are ignored and cannot extend freshness. Frames only age observations; they never advance gait or position. Distance phase uses a 1.2 metre stride and bounded 0.38 radian limb swing. No prediction or continuous gait between snapshots. Disconnect/missing crew removes the existing avatar node. Reconnect gets a new neutral first sample.

Provenance: Frontier Systems project, Codex-assisted independently authored MIT GDScript, Godot CapsuleMesh/BoxMesh and materials, text editing and ordinary engine rendering. No source artwork, imports, fonts or generative imagery. This milestone document owns asset provenance without overlapping other milestones' shared notices edits.

Verification pending: paid actual world fixture without sockets/ports, canonical snapshot isolation, stationary/stale/reconnect/tick rejection, existing client/navigation/picking regressions; Windows and Linux CI. Native stills when needed to check geometry. Videos paused, no uploads or deployment. Local third-person walker remains its existing capsule.
