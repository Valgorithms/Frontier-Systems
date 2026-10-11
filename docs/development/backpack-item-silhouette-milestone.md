# Backpack item silhouette milestone

Successor to merged PR119 c5f573d8ea0941657138ed87ea83373119c6e2cc, based on current dev-master 7548130dc209743242d622a3b10498c276139620.

Scope: original MIT procedural backpack body, straps and pockets in InventoryItemSilhouettes only. Preserve the existing item pick envelope, stable IDs, canonical observation/material provenance, reach and authority. Reuse the paid finite eight-item dense-tray fixture for geometry, highlight, cache, picking and snapshot regression. No simulation/schema/bootstrap/camera/UI/machinery/avatar changes.

Acceptance pending: focused Windows Godot runtime checks, genuine native still if needed to resolve appearance uncertainty, required Windows/Linux CI and Coordinator review. Internal media only, no videos, ports, services, releases or deployment. Coordinator retains merge acceptance.

## Implementation and local verification

InventoryItemSilhouettes supports both existing prototype/fabricated backpack IDs with a box body, cylindrical shoulders, front and side pockets, two rear straps and a three-piece handle (nine mesh children). Every part shares the original proxy material. Maximum geometry bounds fit the unchanged 0.25 x 0.3 x 0.2 m pick envelope. Existing event-driven rebuild/cap, anchors, observations, reach, picking and canonical owners remain unchanged. Provenance is in THIRD_PARTY_NOTICES.md; no new assets, dependencies or configuration.

Windows Godot 4.7.2 bounded import/startup and five runtime tests pass: dense_world_inventory_tray_test, inventory_item_silhouettes_test, world_inventory_preview_test, world_pointer_picking_test and habitat_visual_details_test (seven gates, zero failures). The existing finite paid eight-item fixture retains exact bills, full canonical/provenance invariance, real center/edge/oblique physics picking, stable command identities, cache, highlight/cleanup and actual paid pickup coverage. Additional assertions cover the canonical backpack's original envelope, body distinction, nine-child bound, every detail's shared highlight/restored role material, five idle frames without rebuild and exactly one bounded rebuild on changed observation. Logs/JUnit: ignored var/ci/backpack-final.

Genuine native Compatibility/OpenGL stills on NVIDIA RTX 3080 Ti were inspected: front pocket and rounded shoulders/handle read distinctly, rear straps and side pocket remain visible, dense-tray context retains all eight neighbors. Native fixture reports zero failures and full snapshot invariance. Stills: ignored var/captures/backpack/gl_compatibility/{front,rear,tray}.png; logs: var/ci/backpack-native.{stdout,stderr}.log. Reproduce with the pinned engine --rendering-method gl_compatibility --script res://tests/godot/dense_world_inventory_tray_test.gd -- --backpack-stills. Camera positioning is test-only; no camera runtime edits. Internal media only, no videos, sockets, ports, services, checkpoint writes, releases, deployment or uploads. No screen-control reservation was used.

Required exact-head Windows/Linux CI remains tracked on PR120; Coordinator retains source/visual and merge acceptance. Headless/native local success does not establish human/controller/VR, Linux GPU or live-network acceptance. Worktree and local evidence are retained for review.
