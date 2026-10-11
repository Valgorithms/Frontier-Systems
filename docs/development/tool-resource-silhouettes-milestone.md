# Tool and resource item silhouettes

Successor to PR108 at a482de1637e2219c26173428678113eb45559f03. Presentation-only scope: original MIT procedural crowbar, handheld extractor and resource-canister silhouettes in the existing habitat world-inventory view. Carried equipment currently has text presentation only; adding a held-object renderer is outside this change.

Audit: all three currently use BoxMesh placeholders. Select a hooked pry-bar profile, extractor grip/nozzle profile and cylindrical canister with collar. Keep original positions, selection anchors, pick envelopes, IDs and observation lifecycle. Do not infer contents, integrity, fitted parts or capabilities from appearance. No machinery animation, camera, bootstrap/UI, canonical schemas or simulation edits.

Verification planned: paid finite-resource no-port fixture, complete canonical snapshot invariance, actual physics picking and unchanged collision envelopes, existing inventory/target regressions, and exact-head Windows/Linux CI. Native still captures may resolve silhouette uncertainty; videos/public media remain paused. No deployment.
