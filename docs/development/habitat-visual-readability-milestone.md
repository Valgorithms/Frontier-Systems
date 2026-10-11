# Habitat visual readability milestone

Base: 82ed214a9dcadb742b1fbaa778f4d7375f229c49. Branch: habitat-visual-readability, draft PR targeting dev-master. No merge, integration push or deployment authorized.

Presentation-only work improves the cutaway floor contrast and native directional shadows, clustered resource silhouettes, supported workbench surfaces, storage tray rims/pedestals and advisory terrain outlines. The original IDs, anchors, collision shapes, reach, native picking, input guards, target feedback, terrain preview and UI panels remain owned by their existing components.

HabitatVisualDetails owns disposable mesh decorations. Resource children inherit existing observation visibility/depletion scale. Tray decoration rebuilds only when the inventory display rebuilds and caps itself at 32 trays. Terrain outlines follow the existing two observed marker positions and retire when observations disappear. No canonical state, schema, persistence, simulation tick or service boundary changes.

Provenance: independently authored first-party MIT GDScript and Godot primitive meshes/materials; ordinary Godot rendering only. No AI image generation, imported artwork/fonts or new creative dependencies. Local captures/logs go under ignored var/ and must not be uploaded or used as public showcase material without future owner clearance through Coordinator.

Verification is in progress. Required evidence: bounded Windows import/startup, preserved target and context interaction regressions, focused decoration lifecycle/anchor checks, actual local graphical captures with Compatibility and Forward+ coverage reported separately. Headless results do not establish GPU appearance, Linux native rendering, physical controller ergonomics or human acceptance.
