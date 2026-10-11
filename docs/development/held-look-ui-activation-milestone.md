# Held-look UI activation milestone

Successor to PR45, base `8499e4f9f0b91906c136171748a2b4e4a7a0058e`. Branch `held-look-ui-activation` targets `dev-master` as a draft PR. One agent; no merge, deployment or media publication.

## Acceptance scope

Inject pointer and keyboard input through the actual client Window/SubViewport dispatch. Activate a real UI control with RMB held and Left Alt exposing the cursor. Check Alt release, Escape and window focus loss/recovery, focused coordinate editing, no unintended world selections or commands, and byte-identical canonical snapshots. Reuse PR45 domain/client seams in a dedicated fixture and bounded runner; leave its fixture, PR46 integrated script and inventory fixture untouched. Any repair is restricted to demonstrated presentation/input ownership behavior.

## Evidence

Pending focused headless/native execution. Physical mouse/keyboard, human usability, controller, VR and Linux graphical acceptance remain unverified. Captures and temporary profiles stay ignored/internal. No sockets, fixed ports, core, schema, persistence or asset changes are in scope. First-party test code is independently authored MIT; ordinary engine captures use existing procedural assets without generative imagery.
