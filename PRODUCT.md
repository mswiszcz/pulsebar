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
- Polls configured homelab servers on the LAN every 10 s in the background, whether or not the panel is open, and every 60 s after 3 consecutive failures. Opening the panel refreshes stale readings. Unreachable servers are simply unreachable away from home.
- History is kept in memory for about 5 minutes and discarded on quit.
- Clicking an app row expands its processes; Activity Monitor is one link away.
- Process details (role, working directory, uptime) are read only while the panel is open. Docker containers are polled every 15 s only while the panel is open or Docker is a top app.

## Capabilities and Constraints

- Swift Package Manager only; Command Line Tools, no Xcode. No third-party dependencies.
- Processes owned by root or other users cannot be read without root and are not listed.
- Menu bar label: pressure-colored memory symbol, memory used %, CPU %.
- Expandable app rows: top 5 processes with role (Chromium/Electron `--type`, Firefox `-contentproc`), working directory for non-bundle tools (`claude`, `node`), uptime. Docker expands to running containers from the Docker Engine API.
- Growth badge: an app that grew ≥ 500 MB over the last 10 min is flagged on its row.
- Homelab servers: a panel section with one row per node_exporter server on the LAN (CPU, RAM, VRAM for AMD GPUs, uptime), expandable into 5-minute tracks, load, disk, network and GPU memory. Panel only: the menu bar and notifications stay about this Mac.
- Pressure alerts: a notification when pressure stays at warning or critical for 10 s, naming the biggest grower or the biggest app. Never on "used %".
- Settings: launch at login, pressure notifications and their level, homelab servers.
- No process killing.

## Product Principles

- Pressure first: whether memory is short matters more than how much is "used".
- Name the culprit: group processes by owning app.
- Glanceable over exhaustive: Activity Monitor exists for depth.
- Cheap to run: a monitor must not become the outlier.
