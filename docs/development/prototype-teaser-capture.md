# Prototype teaser capture

Owner-requested 24-second local Telegram teaser, using Godot 4.7.2 native Movie Maker and ordinary FFmpeg editing. The route extends the existing machinery integration test: finite source material is extracted, refined and assembled through real commands before the scene is retained. The recorded commands build, dismantle and rotate a wall from one recovered plate, pack and relocate the fitted printer, replace an extractor head with a refinery head, and refine its actual 1 kg ice into water. Final snapshot validation and finite-material checks must pass.

Existing ProceduralHabitatPreview, MachineryPreview and inventory meshes are rendered from current owner observations. Static close camera shots, capture-only lighting and compact edge captions differ from normal presentation. The normal HUD is hidden so it cannot obscure the machinery or wall. Debug labels, fixture IDs and the preview avatar are hidden. No canonical state grants, fabricated receipts, service listeners, external sends, new fonts/assets, generative image tools or game release are involved. Captions use the existing engine UI font. First-party geometry/capture code is MIT; existing engine font remains part of the engine runtime, not an added redistributed asset.

Run in a clean isolated worktree after import:

```powershell
./tools/ci/capture-telegram-teaser.ps1 -Godot 'D:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' -OutputDirectory 'D:/GitHub/Frontier Systems/var/captures/telegram-teaser'
```

The wrapper owns one bounded native process, disables external telemetry, isolates the user directory and removes its temporary override. It never opens a socket or touches the regular saved world. Capture is graphical on Windows using GL compatibility. Automated fixture and camera operation are disclosed onscreen; this is not footage of human play, controller/VR acceptance or a published build. Local media can be given to the owner for the explicitly requested personal teaser; no Telegram upload is performed by this route.

Review native keyframes before encoding. Use H.264/yuv420p MP4, 1280x720, 30 fps and faststart for mobile sharing. Keep raw provenance and output hashes alongside ignored local media; do not add current internal gallery images to the teaser or upload it to other services.
