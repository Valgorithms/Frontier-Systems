# Tutorial readiness evidence

Readiness review in progress for the [basic gameplay tutorial milestone](basic-gameplay-tutorial-milestone.md).

Pinned runtime base: `1b973cabfadd8dab3c44bd46514590bacaabfc0b` (equipment PR #34 merged). This branch changes verification tooling and documentation only. Source prototype verification does not establish a public demo or human tutorial acceptance.

## Reproduce locally

Reserve loopback ports 27849 and 27850 through Coordinator, then run the bounded route from a clean isolated worktree:

```powershell
./tools/ci/run-tutorial-readiness-checks.ps1 -Godot 'D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' -PortsReserved
```

The wrapper uses the existing headless and graphical runners sequentially, refuses an existing project override, creates a unique Godot user profile, pins HEAD in an ignored manifest, and captures ordinary native-renderer output under ignored `var/ci/tutorial-readiness/`. It never stops an existing listener. The unique user profile remains local for evidence review; remove only its exact directory after review. Existing configuration and capture environment are restored. `-PortsReserved` asserts a Coordinator reservation and does not acquire it.

## Acceptance boundary

The headless cooperative test uses direct authenticated commands. The graphical route instantiates the actual client, advances character physics and invokes contextual guide methods. It disables local keyboard sampling. Neither route proves that a human can discover controls, move/look with physical keyboard/mouse, select the intended UI target, complete the loop unaided or save/reconnect through the client UI. Do not record those routes as human tutorial footage.