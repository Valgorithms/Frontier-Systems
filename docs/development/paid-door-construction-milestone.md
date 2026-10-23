# Paid manual door construction checkpoint

Status: design checkpoint sent to the Frontier Coordinator; implementation and acceptance pending.

## Bounded outcome

Construct, operate and disassemble one paid floor-mounted manual door in an empty wall gap. The assembly uses a fixed 1000 x 2000 x 100 mm installation envelope on the existing 50 mm wall grid. It does not cut a wall, create an airlock, connect gas volumes or establish pressure sealing. Existing first-party code and data are MIT; no external art or source is imported.

## Ownership and transaction

- Production owns installation identity, floor anchor, orientation, constructing principal and the conserved trusted bill: 2,000,000 mg processed plate for frame and leaf. IDs derive from principal and request identity. Player payloads cannot supply bills, actuator capabilities or owner IDs.
- AccessControlSystem owns the installed manual ActuatorState. Construction commissions one released-latch actuator without a controller, circuit, spare modules, bypass grants or prototype airlock contents. Existing manual actuation validation remains authoritative.
- Inventory owns the actor body and actual held crowbar; Tools owns its usable capability. Reach, permission, revision and actual tool checks precede manual operation. Fixed-tick commands and retained exact-intent receipts prevent duplicate debit/refund.
- Prepare the entire Production and Access candidate before commit. Recheck finite stock, active reservations, output capacity and geometry. Commit synchronously without external effects; reject failures without changing either owner.
- Disassembly requires a closed door and no active bypass work or installed foreign hardware. Refund only the retained trusted bill, never fixture contents, and remove only the commissioned device.

## Geometry and persistence

Reserve the complete installation envelope against existing walls, machines, fixtures and other doors even when open. Closed leaves block canonical movement and produce derived collision; open leaves permit passage. Reject closure onto a body. This floor-mounted prototype occupies an empty wall gap; arbitrary wall openings, surface/ship attachment and swept hinge simulation remain outside scope.

Production save v10 adds a bounded door registry; saves v1-v9 migrate to an empty registry. Validate exact commissioned device/actuator links and supported hardware before any world restore mutates state. Access remains the canonical owner of position and condition. Door geometry never enters the existing geometric closed-room query as a solid wall.

## Acceptance

Use finite extracted/refined/processed stock to build, operate, save/restore and disassemble the real assembly. Check exact conservation, request replay, stale revisions, foreign actors, reach, absent/broken tool, insufficient stock, active reservations, occupied closing, overlapping placement, malformed records, orphan/cross-bound links and failed preparation rollback. Preserve the legacy fixture and older saves.

Expose a small player control path through the existing production ingress and owner observations. Reuse Windows/Linux CI and inspect the actual synthetic tested revision and parents plus both export manifests/checksums. Local Godot requires the Coordinator's explicit exclusive bounded no-port lease and a fresh process check. No capture, port, media, deployment or successor work is authorized here.
