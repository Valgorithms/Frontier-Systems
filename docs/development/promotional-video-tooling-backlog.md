# Future promotional video tooling

Status: planning backlog only. Paid playable-scene work, including PR149, keeps
priority. This plan authorizes no capture, heavy native workload, publication,
spending, deployment or production-server access. The existing internal-media
boundary remains in effect. Coordinate a fresh resource lease before future
runtime work; Gaia's current restore cycle must not be interrupted or presumed
finished from an earlier completion notice.

## Intended outcome

Create short entertaining scenes using genuine game actions, existing rights-cleared
human-made assets and sounds. A staged scene should have a clear action and payoff,
with the camera looking at the object being used. Avoid passive camera tours,
cluttered UI and shots that hide the interaction. No disclaimer overlays by default;
end cards are optional and require an appropriate, explicitly chosen use.

Offline sprite-cutout skits are an approach to evaluate, not a requirement to copy
Civ13 material. Reference access does not establish redistribution rights. Check
each asset's provenance and the project's MIT/CC0 policy before reuse. No
generative artwork, textures, fills or intermediate images.

## Bounded implementation sequence

1. Audit the retained PR85 capture tooling and current character/camera controls.
   Reuse working parts; inventory actual limitations in assets, animation, camera
   smoothing and interaction framing before creating another capture runner.
2. Define a versioned scene cue sheet: seed, starting checkpoint, actor IDs,
   authenticated action sequence, tick deadlines, camera targets and expected
   outcomes. Actor direction must use normal validated commands, with no privileged
   mutations or model-controlled runtime authorization.
3. Add isolated scene staging and reset support. Restore a verified checkpoint,
   reset presentation separately, and verify canonical state, receipts, RNG state,
   gas and material totals. Repeatability means identical command outcomes and
   state digests; do not promise byte-identical rendered video.
4. Add camera cues that track the interaction target, preserve sight lines and
   smooth movement without hiding action. Frame the actual actor and object;
   validate both first-person aim and external shots. A recording UI profile may
   collapse panels while retaining necessary interaction feedback. It must not
   change simulation behavior.
5. Define landscape and vertical export profiles with explicit resolution, aspect
   ratio, frame rate, codec and audio settings. Frame each aspect deliberately
   rather than blindly cropping landscape. Discover installed tools through the
   existing bounded resolver. Use local output and no paid services.
6. After separate capture authorization and resource availability, produce one
   short internal scene for owner review. Verify video metadata, audio levels,
   target visibility, UI clearance, coherent action and continuity after reset.
   Retain source revision, cue sheet, checkpoint digest, tool versions, asset
   provenance, logs and output checksum beside the artifact.

## Admission and acceptance

Before implementation, assign one owner and isolated worktree, define a narrow
first scene and inspect existing tooling. Before native execution, obtain an
exact-head exclusive resource lease and confirm Gaia and other workers are not
using the required resources. Stop at the first diagnostic under the agreed lease.

An initial acceptance scene must show a real validated interaction and its visible
result, repeat correctly after reset, keep its subject visible in both planned
aspect ratios, and avoid obstruction by UI. Source tests and CI establish command
and reset contracts; genuine rendered review establishes camera and motion quality.
No public release or posting follows automatically from technical acceptance.
