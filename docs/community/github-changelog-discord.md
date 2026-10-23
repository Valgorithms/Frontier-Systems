# GitHub to Discord player changelogs

Existing [issue routing](github-issue-discord-routing.md) already creates bug/suggestion forum threads on routing labels and posts closures to their original threads. The general read-only GitHub feed remains separate. This extension adds reviewed player summaries in dedicated read-only #changelog through GitHub Actions, following Civ13's behavioral contract independently; no upstream code is imported.

The reviewed **player release** workflow remains manual-dispatch only on `dev-master`. A separate, default-disabled **Discord merged PR changelog** workflow can announce an explicit PR description field after merge into `dev-master`. Merges, pushes and CI passes do not establish an available game version. Neither publisher deploys the game, and there is no deployment-status integration.

Repository Actions configuration:

| Name | Type | Value |
| --- | --- | --- |
| `DISCORD_CHANGELOG_WEBHOOK_URL` | Secret | Dedicated incoming webhook; never record its URL |
| `DISCORD_CHANGELOG_CHANNEL_ID` | Variable | `1558871000383234182` |
| `DISCORD_CHANGELOG_ENABLED` | Variable | Absent/false until approved activation |
| `DISCORD_MERGE_CHANGELOG_ENABLED` | Variable | Absent/false until separately approved merge-announcement activation |

The webhook must belong to Frontier guild `1558661083131019364` and that channel. URLs are HTTPS `discord.com` incoming webhook paths only; redirects and extra URL components are rejected. The publisher logs no response bodies or credential-bearing errors. Issue text and manifests are data, never shell code. Discord mentions are disabled.

Setup on 2026-10-11: the dedicated text channel's inherited read-only permissions were checked. The owner manually configured the posting secret; GitHub API inspection confirmed its name and the exact channel variable, without reading the secret value. Activation remains absent. Secret-name presence does not prove the saved webhook works; no live send or game availability has been verified.

Behavioral reference reviewed: Civ13 commit `039cdc98a4086fb83057b2c366479cb2d90e6095`, `.github/workflows/changelog.yml` and `tools/changelog/README.md`. Frontier implementation is independently authored; no source/assets were copied.

Remote branch `discord-changelog-receipts` was provisioned from `dev-master` at `f58fe715b3e8aa087f665b9cf8ea4d30744ba3bd` on 2026-10-11, before activation. Keep it permanently; never merge it into gameplay or delete its records. The manual publisher writes `receipts/<manifest-id>.json`; merged PRs use the separate `receipts/merged-pr/<number>.json` namespace. Both workflows share non-canceling concurrency group `discord-player-changelog` with `queue: max`. Optimistic GitHub file SHA checks fail closed on conflicting state writes.

After reviewing a [manifest](../../changelogs/README.md), dispatch **Reviewed Discord player changelog** on `dev-master` with its ID and exact full game SHA, leaving `dry_run=true`. This prints only the intended public text and performs no network requests or receipt writes. After separately approving publication and confirming that exact integrated SHA is available to players, enable the variable and dispatch with `dry_run=false`, `confirm_live=true`. Neither operation deploys anything. No live game publication is authorized merely by configuring this feature.

Before each Discord POST a durable pending receipt is saved. Confirmed message IDs are then saved as sent. Known sent chunks are skipped; changed manifests and pending/invalid receipts block replay. Network errors, HTTP errors (including rate limits), invalid confirmations or failed post-send state writes leave pending. No blind automatic POST retry runs. Inspect the exact Discord destination and receipt: if delivered, record the actual message ID as sent; if positively proven undelivered, remove only the pending final chunk in a reviewed state commit. Uncertain delivery stays blocked. GitHub and Discord cannot provide a shared exactly-once transaction.

Local `node --test tools/github/changelog-discord.test.mjs` checks admission, bounded payloads, mention suppression, durable reservation, ambiguous delivery, state failures, partial batch recovery and changed-content rejection with injected transports. Existing issue tests remain in the Windows/Linux Actions matrix. Offline checks do not prove live Discord delivery or game availability. No game media is posted.

## Optional merged-PR announcements

Use exactly one visible line in the PR's opening description:

```text
Changelog: Fixed assembly consuming materials after cancellation.
```

After separately approved activation, merging into `dev-master` posts exactly `- Fixed assembly consuming materials after cancellation.` to the existing Frontier #changelog. This matches Civ13's bullet format; no PR title, comments, linked issue, commit scraping or generated summary contributes text. Review establishes whether the field is meaningful and accurate. It announces integration only, without a deployment or availability claim. Use one announcement route per change; do not repeat a merged-PR entry in a manual release manifest.

Missing, null or blank fields mean no post and require no credentials, HTTP requests or receipt writes. HTML comments, fenced code, quoted and indented examples do not opt in. More than one field, placeholders (`required`, `TODO`, `TBD`, template instructions), mentions, angle brackets, controls, bidi overrides and entries over 1500 UTF-16 units fail closed. Actual text must be on the same line, including after Windows CRLF/CRCRLF conversion. No multiline continuation is inferred. Shell syntax is plain JSON text and never executed. Every PR description edit reruns the same parser in secret-free Windows/Linux contracts, regardless of changed paths.

The privileged workflow subscribes only to `pull_request_target: closed` on `dev-master`; its job also requires the exact repository, `merged == true` and `DISCORD_MERGE_CHANGELOG_ENABLED == 'true'`. There is no manual dispatch, push or deployment trigger on this route. It checks out the event's trusted base-branch `github.sha` with persisted Git credentials disabled, never a PR/fork head or downloaded PR artifact. Only the publisher step receives the webhook and token. First-party automation at that already-integrated revision is trusted; unmerged PR code never runs with these credentials. All PR checks use `pull_request` and read-only contents access without secrets.

The script repeats context checks, refetches repository/PR metadata, confirms the exact merged SHA and default-branch ancestry, and verifies incoming webhook type plus the fixed Frontier guild and channel. The frozen event description is used for retries even if the PR description later changes. Its GITHUB_TOKEN has only `contents: write` (required for durable receipt PUTs) and `pull-requests: read` (merge confirmation); all other permissions are absent. GitHub's contents permission cannot be scoped to a branch/path; code restricts writes to the existing receipt branch and merged-PR namespace. GitHub authorization is never sent to Discord; redirects and automatic HTTP retries are disabled. Error logs contain neither PR text nor remote bodies/credential-bearing errors.

A merged-PR receipt has `schema: 1`, the exact repository, PR number, merge commit, channel, full bullet content, `status: pending|sent`, and `message_id`. It is saved as pending **before** POST and updated to sent only after a valid message/channel confirmation. Confirmed receipts suppress duplicates. Changed content, malformed records, pending reservations, read/write conflicts, timeouts, 429/5xx responses or uncertain post-send state writes block replay. A failed pending write sends nothing; an uncertain pending write also needs reconciliation. There is no exactly-once transaction between GitHub and Discord.

For a pending merged-PR receipt, inspect the exact channel and `discord-changelog-receipts:receipts/merged-pr/<number>.json`. If delivered, a separately reviewed state correction may mark it sent with the actual message ID, preserving identity/content. If positively proven undelivered, a separately reviewed correction may remove that one reservation before rerunning the original workflow. Uncertain delivery stays pending. Never delete records to bypass uncertainty or replay through a manual manifest.

The shared max queue retains up to 100 pending runs; overflow runs are canceled. Check canceled runs after large merge bursts and rerun the **original** run when space is available, preserving its event snapshot and receipt identity. Pending receipts still require reconciliation first. Source tests guard the two publishers' exact queue settings because actionlint 1.7.12 does not yet recognize `queue`; ignore only its unsupported-key diagnostic when linting, never other workflow errors. [GitHub's queue contract](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-workflow-concurrency) documents this limit.

### Setup and activation status (2026-10-23)

Read-only GitHub inspection reconfirmed the repository secret **name** `DISCORD_CHANGELOG_WEBHOOK_URL`, channel variable `1558871000383234182`, and existing receipt branch. Neither activation variable was present. No webhook value was retrieved, copied or reconfigured, and no Discord request or live test was made. Existing setup is established by merged PR [#83](https://github.com/Valgorithms/Frontier-Systems/pull/83); secret-name presence alone does not prove the saved credential works.

Keep both activation flags absent/false. After review/merge and explicit owner approval to enable automatic external posting, an authorized maintainer may set repository Actions variable `DISCORD_MERGE_CHANGELOG_ENABLED=true`. This is a separate approval from source-PR creation or merge. Do not change `DISCORD_CHANGELOG_ENABLED`, create credentials, alter security controls or send a test message as part of this port. The required destination is the existing read-only #changelog, guild `1558661083131019364`, channel `1558871000383234182`; any replacement secret/destination setup requires its own approval. The publisher verifies that destination at execution time. It does not automatically backfill merges skipped while disabled.

Behavioral source pinned at Civ13 `580a7399d3060c5ba38c8782da8e87411d2650ab`: [merge workflow](https://github.com/Civ13/Civ13/blob/580a7399d3060c5ba38c8782da8e87411d2650ab/.github/workflows/changelog-merge.yml), [publisher/parser](https://github.com/Civ13/Civ13/blob/580a7399d3060c5ba38c8782da8e87411d2650ab/tools/changelog/publish.mjs), [PR checker](https://github.com/Civ13/Civ13/blob/580a7399d3060c5ba38c8782da8e87411d2650ab/tools/changelog/check-pr.mjs), [contracts](https://github.com/Civ13/Civ13/blob/580a7399d3060c5ba38c8782da8e87411d2650ab/tools/changelog/merge.test.mjs) and [guidance](https://github.com/Civ13/Civ13/blob/580a7399d3060c5ba38c8782da8e87411d2650ab/tools/changelog/README.md). Civ13 is AGPL; this MIT implementation expresses the contribution and delivery requirements independently and imports no source files/assets or dependencies. See the [reference manifest](../research/reference-manifest.csv). Civ13's game/test/upload/deployment workflows and credential values are outside this port.

Run `node --test tools/github/issue-discord.test.mjs tools/github/changelog-discord.test.mjs tools/github/pr-changelog.test.mjs` and `node tools/github/changelog-discord.mjs --validate` with Node 24. Tests use injected HTTP transports and fake credentials only; no live service acceptance is claimed.

## Historical manual-publisher implementation acceptance

PR83 head `523e1434b3878b3436189251652c4c0c8ef6b0e5` merged as `4ecfad52c75e837f458f777a42b46f1f53587311` after all 13 exact-head checks passed. CI `38153946534` tested synthetic `8730e9100fda1cdd3708f4c8b70fafbd45876445`; both OS notification contracts passed in `38153946630`. Local Node 24.21.0 ran 14 changelog and eight unchanged issue contracts successfully. The default-branch workflow is registered. No real changelog message, webhook delivery or available game version is claimed; activation remains absent.
