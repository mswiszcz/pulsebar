# Product

<!-- impeccable:product-schema 1 -->

## Platform

macos

## Users

One developer on an Apple Silicon Mac running browsers, Electron tools, several AI coding sessions and a Docker VM at once. They glance at the menu bar while working and open the panel when the machine feels slow, to find out whether memory is actually short and which app is responsible.

## Product Purpose

Pulsebar is a menu bar utility that shows real system load: memory pressure (the kernel's view, not "Memory Used"), the apps behind it, CPU, disk and network. Success is answering "is my Mac actually struggling, and who is to blame?" in one glance without opening Activity Monitor.

## Positioning

It reports memory the way the kernel judges it — pressure level and `kern.memorystatus_level` — and rolls helper processes up into their owning app (Firefox tab processes into Firefox, Docker's VM into Docker), so the outlier is named directly.

## Operating Context

- Lives in the macOS menu bar (SwiftUI `MenuBarExtra`, window style); no Dock icon.
- Samples every 2 s; disk free space every 30 s.
- History is kept in memory for about 5 minutes and discarded on quit.
- Clicking an app row opens Activity Monitor.

## Capabilities and Constraints

- Swift Package Manager only; Command Line Tools, no Xcode. No third-party dependencies.
- Processes owned by root or other users cannot be read without root and are not listed.
- Menu bar label: pressure dot, memory used %, CPU %.
- No settings, no login item, no process killing.

## Product Principles

- Pressure first: whether memory is short matters more than how much is "used".
- Name the culprit: group processes by owning app.
- Glanceable over exhaustive: Activity Monitor exists for depth.
- Cheap to run: a monitor must not become the outlier.
