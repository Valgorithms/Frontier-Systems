# Local walker humanoid silhouette

Replace the local third-person capsule with original MIT primitive head, torso, arms and legs. The visual helper owns disposable geometry only. The exact existing capsule collider, movement/input, camera rig, canonical host position, command sampler and persistence remain unchanged. A static neutral silhouette is deliberate: this milestone adds no inferred locomotion or pose state.

Scope: local_habitat_character.gd visual construction, a local-only helper, focused socket-free actual-shell tests and this milestone. Observed avatars/bootstrap, machinery and backpack presentation are excluded.

Provenance: independently authored Frontier Systems MIT GDScript geometry using Godot primitives and plain text editing. No source artwork, third-party creative assets or generative imagery.

Acceptance: real shell physics and barriers, first-person subtree hiding, third-person visibility and camera arm behavior, unchanged world snapshots and command queue. Windows local runner and exact-head Windows/Linux CI are required. Native internal stills resolve silhouette readability only if needed; no videos, publication or deployment.
