# Terrain parcel return milestone

Base: current origin/dev-master `8bcc1b4331dcf2b312b2131fd28ac89953496215`, including PR18. Isolated `codex/terrain-return`; work in progress, no acceptance claimed.

The reviewed bounded design adds terrain checkpoint v3: original immutable v1 claim receipt and nullable permanent holder return receipt remain in every lifetime association. The 128 lifetime slots are never released. A return atomically removes one owned whole prototype parcel, assigns its existing canonical transfer to the authenticated holder's escrow, and contributes zero inventory payload mass thereafter. The existing fill path consumes that escrow with exact provenance. Returned transfers cannot be claimed again. Claim retries return the identical original receipt, including after fill; retries never create an item.

Legacy v1/v2 migrate only from their validated canonical transfer records. Return has independent principal ordinals and immutable original revision intent, sharing the existing tick ingress budget and one unresolved client journal. Chronology-aware permission rewind validates cross-principal return and fill. No Production consumer, arbitrary inventory recycling, bootstrap, budget, deployment or graphical change is included.

Verification will cover whole holder return, cross-principal movement, changed/stale/foreign/forged rejection, snapshots at each lifecycle stage, partial/full fill, unchanged claim retries, lost acknowledgement and both-end restart/reconnect. Port19243 is Coordinator-reserved for the new cooperative suite. No graphical acceptance or media publication is claimed.
