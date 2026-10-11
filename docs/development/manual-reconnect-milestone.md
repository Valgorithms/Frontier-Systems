# Manual source-playable reconnect

The client offers a persistent **Reconnect to shared host** button after disconnect or a failed connection. It reuses operator environment configuration without displaying or saving host/invite credentials. One pending connection is allowed; actions wait for authentication and a fresh observation. Rejection remains visible and retryable.

Disconnect clears adapter observations, world previews, crew avatars, movement bookkeeping and displayed hands/inventory. Production presentation is rebuilt against the same remote adapter after fresh data. Pending construction/inventory/checkpoint commands are abandoned with unknown outcomes and never resubmitted. The existing bounded terrain journal and explicit original-intent retry remain unchanged. Canonical world state and identity belong to the host; no schemas or core authority change.

Draft [PR #53](https://github.com/Valgorithms/Frontier-Systems/pull/53) targets dev-master from `manual-client-reconnect`, based on `834bea7dd9e581f4fc2ddd6f9f80ef52f0584ec6` (includes PR #49). No external services, public host, deployment or merge.

## Verification

Windows Godot 4.7.2 dedicated adapter/shell checks pass: initial/duplicate suppression, authentication without a fresh observation, abandoned command completion, stale projection clearing, failed attempt and rejected authentication recovery. The same running actual client also passes disposable loopback checkpoint save, disconnect, unavailable-host attempt, real invite rejection and manual reconnect to a restored host. It retains body/slot, items, active hand, inventory revision, production stock/deposits/walls/structures/components and the integer-normalized original terrain intent. Reconnect transmits no abandoned command or automatic terrain retry. The synthetic retained return targets an absent fixture parcel; it proves preservation and explicit retry availability, not successful terrain settlement.

The selected final Windows run passed all 11 checks: import, startup and the nine scripts listed below, including existing two-client finite engineering/checkpoint acceptance and inventory/production shell regressions. `git diff --check` passed. PHP and domain schemas are unchanged; their cross-platform checks remain CI evidence.

Use the existing runners:

```powershell
./tools/ci/run-godot-checks.ps1 -Godot 'D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' -TestNames manual_reconnect_adapter_test.gd,manual_reconnect_acceptance.gd,first_playable_acceptance.gd,client_inventory_shell_test.gd,integrated_panel_layout_test.gd,first_playable_task_guide_test.gd,recipe_requirements_test.gd,maintenance_requirements_test.gd,equipment_prerequisites_view_test.gd -OutputDirectory var/ci/manual-reconnect-final
./tools/ci/run-first-playable-render-check.ps1 -Godot 'D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' -Route manual-reconnect -PortsReserved -TimeoutSeconds 60
```

Port 27849 requires a Coordinator lease and a fresh free-listener probe before binding. Run the headless route with a disposable custom user profile; the native route creates a unique profile override and removes it in `finally`, preserving an existing override. Test world/checkpoints are ignored under `var/ci/manual-reconnect-world-*`; native logs/provenance manifest are under `var/ci/render-manual-reconnect`, and captures under `var/ci/manual-reconnect-render/captures`. No profile override remains after the checks; only disposable test files are retained as local evidence.

Native OpenGL Compatibility acceptance passes through button-signal activation with real loopback authentication and checkpoint I/O. Ordinary viewport captures of connected/disconnected/rejected/reconnected states were inspected locally; recovery status and button are visible, direct actions disable while disconnected, and production is rebuilt after fresh data. Existing MIT engine geometry is the capture source; no generative art or third-party assets. All captures remain ignored/internal, with no upload.

Automated adapter, headless network and native Compatibility evidence does not establish human usability, physical keyboard/mouse reconnect activation, controller, VR, Forward+, public networking, TLS or Linux graphical acceptance. Windows/Linux CI for the exact final pushed head remains the Coordinator review gate; earlier-head success does not certify the final head.
