# R-001: modern rendering optimization leads

- **Topic:** rendering/performance; engineering-game readability
- **Outcome/status:** proposed; source-checked on 2026-10-25; no project rendering gains reproduced
- **Decision date:** pending
- **Project snapshot:** `b19e99ffd964006c4e590435239a8f17adbd62d5` on dev-master
- **Next step:** [E-001: controlled baseline and shared wall resources](../experiments/E-001-rendering-baseline.md)

## Sources and access

All access/review dates below are **2026-10-25**. Godot 4.7 pages were opened alongside the supplied stable aliases; versioned URLs narrow context but remain mutable, without a captured documentation commit.

| ID | Source/title | Author/publisher | Publication date | Reviewed version/context |
| --- | --- | --- | --- | --- |
| V1 | [Tutorial: How To Optimize Almost Every Step In Modern Game Rendering](https://www.youtube.com/watch?v=SnNm7rSSvlg) | Threat Interactive | Unverified | Video ID SnNm7rSSvlg; title/channel supplied by parent review. This pass's public video/oEmbed fetches were throttled. |
| D1 | [Optimizing 3D performance](https://docs.godotengine.org/en/4.7/tutorials/performance/optimizing_3d_performance.html) | Godot documentation contributors | Not stated on reviewed page | 4.7; culling, automatic/manual instancing and lighting |
| D2 | [3D antialiasing](https://docs.godotengine.org/en/4.7/tutorials/3d/3d_antialiasing.html) | Godot documentation contributors | Not stated | 4.7; MSAA, TAA and FSR2 |
| D3 | [Occlusion culling](https://docs.godotengine.org/en/4.7/tutorials/3d/occlusion_culling.html) | Godot documentation contributors | Not stated | 4.7; mechanism, bake limits, moving occluders and runtime comparison |
| D4 | [MultiMesh](https://docs.godotengine.org/en/4.7/classes/class_multimesh.html) | Godot documentation contributors | Not stated | 4.7 class description; group visibility/AABB and light limits |
| A1 | [RDNA Performance Guide](https://gpuopen.com/learn/rdna-performance-guide/) | AMD GPUOpen | 2023-03-22 originally posted; later update date unverified | Mutable guide with RDNA 3 updates; command buffers, PSOs, barriers and memory |
| G1 | [Introducing Reverse Z](https://godotengine.org/article/introducing-reverse-z/) | Clay John / Godot | 2024-04-29 | Historical 4.3 introduction and shader compatibility note |

V1 coverage is inherited evidence from the parent research review: **3,235 caption segments through 2:00:36 of a 2:01:25 video**, obtained through [LinkTranscript](https://linktranscript.com/result?url=https%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3DSnNm7rSSvlg). The caption service retained an older title and transcription errors. This pass could not independently retrieve that page; the final 49 seconds/outro remain unverified. No full transcript or benchmark assets are copied here.

## Claims versus evidence

| Lead | Source claim/context | Independently checked here | Limit / project inference |
| --- | --- | --- | --- |
| Rendering pipeline changes | Parent's V1 review identifies optimization ideas; many GI, AA and motion-blur sections are explicitly unfinished proposals | No video technique or benchmark was reproduced | Treat as investigation leads; no compounded percentage or whole-game gain |
| Repeated geometry | D1 documents Forward+ automatic instancing for shared mesh/material resources, with transparency restrictions | Pinned wall code constructs distinct resources; see audit below | Sharing is a small first hypothesis; no measured speedup |
| Image stability/readability | D2 describes MSAA's edge coverage limits and TAA's shader/specular coverage with camera-motion blurring/ghosting risks; FSR2 can run at native resolution with added cost | Documentation checked, no capture comparison performed | Assess moving cables, panel edges, labels and selection feedback, not only still screenshots |
| Hidden rooms | D3 describes CPU occlusion rasterization, setup/CPU overhead and static bake constraints; moving occluders can require BVH rebuilds | Documentation checked, no dynamic-room experiment performed | Doors and demolition must retire occlusion immediately when view opens; stale occluders are a correctness failure |
| Low-level renderer work | A1 discusses submission/state/barrier/memory costs for RDNA/DX12/Vulkan | Vendor guidance checked, no native experiment | Godot owns these mechanisms; RDNA tuning is not a universal RTX result or an instruction to modify the engine |
| Depth precision | G1 introduced reverse-Z in Godot 4.3 | Historical primary source checked | Already engine functionality; no new Frontier reverse-Z project |

D4 cautions that MultiMesh groups instances as one spatial object with an encompassing AABB and shared per-object lighting limits. Grouping an entire base could worsen visibility/light behavior; consider spatial batches only if simpler sharing leaves a measured bottleneck.

## Pinned Frontier evidence

The following are source observations at the stated commit, not runtime results from this pass:

- [project.godot](https://github.com/Valgorithms/Frontier-Systems/blob/b19e99ffd964006c4e590435239a8f17adbd62d5/project.godot) declares 4.7 / Forward Plus, Windows D3D12, 1920x1080 viewport/window defaults and 60 Hz physics. [CI](https://github.com/Valgorithms/Frontier-Systems/blob/b19e99ffd964006c4e590435239a8f17adbd62d5/.github/workflows/ci.yml) selects Godot 4.7.2. Defaults do not prove actual runtime viewport sizes or minimum hardware.
- [The October 9 report](https://github.com/Valgorithms/Frontier-Systems/blob/b19e99ffd964006c4e590435239a8f17adbd62d5/reports/performance/2026-10-09-baseline.md) describes a working tree based on f830bcb with uncommitted changes, five-second warmup and one fifteen-second session per profile. Habitat rendering was **523x504**, root **1152x648** despite a requested 1280x720 window. It explicitly identifies unresolved pacing near 75/120 Hz and changes both renderer and driver. Its FPS difference is not a clean renderer-throughput comparison or an exact-b19e99f measurement.
- [ProceduralProductionPreview._update_spatial_walls](https://github.com/Valgorithms/Frontier-Systems/blob/b19e99ffd964006c4e590435239a8f17adbd62d5/src/presentation/production/procedural_production_preview.gd) creates a BoxMesh and material per new wall before calling [EngineeringObjectDetails.wall](https://github.com/Valgorithms/Frontier-Systems/blob/b19e99ffd964006c4e590435239a8f17adbd62d5/src/presentation/production/engineering_object_details.gd). That helper replaces the panel mesh/material, then creates eight decorative boxes, each with its own mesh/material. Source-level expansion gives **10 BoxMesh and 10 StandardMaterial3D constructions per newly created wall**: initial panel 1 + replacement 1 + details (2 + 2 + 2x2). One panel pair is replaced before attachment; this arithmetic is not a retained-memory, allocation-byte, draw-call or GPU-timing measurement.
- [SpatialWallConstruction](https://github.com/Valgorithms/Frontier-Systems/blob/b19e99ffd964006c4e590435239a8f17adbd62d5/src/core/production/spatial_wall_construction.gd) caps canonical prototype walls at **32**. Therefore 100/1,000-wall tests are isolated presentation stress fixtures, not supported gameplay populations or authorization to raise that cap.
- [The existing client benchmark](https://github.com/Valgorithms/Frontier-Systems/blob/b19e99ffd964006c4e590435239a8f17adbd62d5/tools/godot/benchmark_client.gd) collects viewport render times, frame intervals and resource gauges. It uses a stationary main scene and writes renderer/rate-qualified reports. It does not provide the moving-camera, wall-count or per-pass experiment automatically. [Tick profiling](https://github.com/Valgorithms/Frontier-Systems/blob/b19e99ffd964006c4e590435239a8f17adbd62d5/docs/architecture/tick-profiling.md) excludes rendering/GPU and is a different measurement boundary.

## Relevance, costs and decision

Repeated resource construction offers a narrow presentation experiment while preserving canonical wall ownership, collision, selection and persistence. Shared resources need complete immutable cache keys; mutating a shared highlight/material can accidentally change every wall. Decoration, shadow passes and CPU scene traversal may dominate even after sharing. Wall removal/recreation needs bounded cache retention.

A future comparison should establish actual 1080p render targets and CPU/GPU/frame-tail timing, then change only resource sharing. Supported AA comparisons and room/shadow budgets follow separately. Dynamic geometry makes baked lighting/occlusion less straightforward; visibility must follow authoritative observations without becoming simulation authority.

**No custom GI, deferred renderer, motion-blur or AA rewrite is justified by this entry.** First identify a measured project bottleneck and preserve motion readability. Runtime reproduction, target lower-end hardware, VR/stereo behavior, video publication date and the unreviewed outro remain open. See E-001 for falsifiable controls and acceptance limits.
