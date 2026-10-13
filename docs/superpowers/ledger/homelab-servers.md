---
tags: [ledger, pulsebar, homelab]
date: 2026-10-13
---

# Ledger: homelab servers

Spec: [[2026-10-13-homelab-servers-design]]. Integration branch: `feat/homelab-servers`. Implementers: haiku subagents.

## Decisions

- No decisions round: the spec's "Decided" table covers every open point; user asked to skip the plan.
- Backoff lives in its own file `PollBackoff.swift` (pure value type) so wave 1 tasks don't collide.
- Settings → store: servers persisted as JSON under `servers`; `StatsStore` watches `UserDefaults.didChangeNotification` and restarts the loop when the decoded list changes.
- `TrackGraph` / `TimelineAxis.minuteTicks` take `sampleInterval` as a required argument.

## Tasks

| # | Task | Depends | Status | Branch | Verified SHA | Next action |
|---|---|---|---|---|---|---|
| T1 | PrometheusText + NodeMetrics + NodeRates + tests | — | merged | hs-t1 | 9e6319e | — |
| T2 | ServerConfig/ServerURL + PollBackoff + tests | — | merged | hs-t2 | 8272d98 | — |
| T4 | TrackGraph/TimelineAxis explicit sample interval, TrackRow height | — | merged | hs-t4 | a6518ed | — |
| T3 | HomelabMonitor actor + ServerTracker | T1, T2 | merged | hs-t3 | b814303 | — |
| T5 | Panel: StatsStore, PanelModel, HomelabList, PopoverView | T3, T4 | dispatched | hs-t5 | — | await report |
| T6 | Settings Servers section, ServerSettings, Info.plist | T3 | merged | hs-t6 | 977f137 | — |
| T7 | Docs: README, PRODUCT.md, design-contract | T5, T6 | pending | — | — | — |

## Pitfalls

- Test files must not `import Foundation` (toolchain lacks `_Testing_Foundation`); keep logic testable without it.
- `swift test` needs `--disable-sandbox` and a run outside the Bash sandbox; use `--scratch-path $TMPDIR/<task>-build`.
