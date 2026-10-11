# Manual source-playable reconnect

The client offers a persistent **Reconnect to shared host** button after disconnect or a failed connection. It reuses operator environment configuration without displaying or saving host/invite credentials. One pending connection is allowed; actions wait for authentication and a fresh observation. Rejection remains visible and retryable.

Disconnect clears adapter observations, world previews, crew avatars, movement bookkeeping and displayed hands/inventory. Production presentation is rebuilt against the same remote adapter after fresh data. Pending construction/inventory/checkpoint commands are abandoned with unknown outcomes and never resubmitted. The existing bounded terrain journal and explicit original-intent retry remain unchanged. Canonical world state and identity belong to the host; no schemas or core authority change.

Verification is in progress on an isolated branch targeting dev-master. Dedicated adapter/shell checks and bounded disposable loopback restored-world acceptance use the versioned Godot runner. Port 27849 is Coordinator leased; no external services, public host, deployment or merge. Automated headless/network evidence does not establish human, graphical, controller, VR or Linux acceptance. Internal captures, if any, remain ignored.
