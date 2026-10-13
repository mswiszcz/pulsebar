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
| T1 | PrometheusText + NodeMetrics + NodeRates + tests | — | dispatched | hs-t1 | — | await report |
| T2 | ServerConfig/ServerURL + PollBackoff + tests | — | dispatched | hs-t2 | — | await report |
| T4 | TrackGraph/TimelineAxis explicit sample interval, TrackRow height | — | dispatched | hs-t4 | — | await report |
| T3 | HomelabMonitor actor | T1, T2 | pending | — | — | dispatch after T1, T2 merge |
| T5 | Panel: StatsStore, PanelModel, HomelabList, PopoverView | T3, T4 | pending | — | — | — |
| T6 | Settings Servers section, ServerSettings, Info.plist | T3 | pending | — | — | — |
| T7 | Docs: README, PRODUCT.md, design-contract | T5, T6 | pending | — | — | — |
