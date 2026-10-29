# HELLION gameplay and mechanics baseline

## Direction

Frontier Systems aims to be as close as practical to a faithful gameplay and mechanics remake of [HELLION](https://steamcommunity.com/app/588210), then add mechanics from other games on top. HELLION is the primary project-wide baseline, not one of several equally weighted inspirations. This direction concerns Frontier Systems, not Civ13.

The original game's [Steam community description](https://steamcommunity.com/app/588210) presents stranded survivors exploring derelict ships and stations and acquiring air, fuel and equipment. The [Steam store page](https://store.steampowered.com/app/588210/HELLION/) attributes HELLION to Zero Gravity and describes a multiplayer space-survival simulation. These public descriptions were consulted on 2026-10-29; they are mutable and do not establish a detailed mechanics inventory or version-specific behavior.

This is a design target, not a claim that Frontier has implemented or verified HELLION feature parity. The current [first playable](../development/first-playable-milestone.md) is a bounded cooperative extraction/refining/recycling prototype. Existing design contracts include project-specific proposals that must not be attributed to HELLION without evidence.

## Order of work

1. **Establish the baseline:** research observable gameplay and mechanics from rights-respecting public material, recording source, game version, access date, coverage and uncertainty in the [research manifest](../research/reference-manifest.csv). Build a reviewable capability map and identify independent acceptance scenarios; do not guess a complete feature list from a store summary.
2. **Build toward faithful gameplay:** prioritize bounded, testable slices of the HELLION baseline and their required simulation, multiplayer, persistence and presentation foundations. Reuse current infrastructure where it serves the target. The existing prototype remains a useful foundation, not a parity milestone.
3. **Layer other mechanics:** after the relevant baseline behavior is understood and established, evaluate additions from other games against it. Civ13 remains the primary reference for the later planet-start civilization extension; Moonbase Alpha and other references contribute secondary ideas. Preserve independently authored rules and explicitly document changes to the baseline experience.

This order sets design priority, not a claim that every prerequisite must be completed before a small playable slice can be tested. For each slice record the target behavior, source and game version, current Frontier status, acceptance scenario and any intentional difference. Where an existing Frontier rule conflicts with a verified baseline behavior, surface the tradeoff for an explicit project decision; do not silently label the difference as parity. Do not infer that an unreviewed HELLION feature exists, or promise exact balance, content, networking or release timing.

## Implementation and rights

Frontier Systems is an independent project and is not presented as officially affiliated with or endorsed by HELLION or Zero Gravity. A gameplay reference does not grant rights to proprietary source code, assets, audio, maps, names, branding, UI layouts or text. Implement independently and use original or rights-cleared materials under the repository's MIT and creative-asset policies. Do not import or adapt HELLION files without independently verified file-level rights and the required approval.

No runtime, content, asset or networking change is made by this design decision. Parity requires feature-specific evidence against identified HELLION versions and separately verified Frontier behavior; no current percentage or full-parity assertion is justified.
