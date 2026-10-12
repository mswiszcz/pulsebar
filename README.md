---
tags: [macos, menubar, swift]
---

# Pulsebar

A small native macOS menu bar utility that shows real system load: memory pressure, the apps using the most memory and CPU, disk and network throughput.

The menu bar shows a pressure dot, memory used % and total CPU %, e.g. `● 62% · 14%`. Click it for the detail popover.

Requires macOS 14+. Menu-bar only (`LSUIElement`), no Dock icon, no settings, no login item.

## Build, run, install

Works with the Command Line Tools alone (no Xcode).

| Command | What it does |
| --- | --- |
| `make build` | `swift build -c release`, assembles `build/Pulsebar.app`, ad-hoc signs it |
| `make run` | builds and opens the app |
| `make install` | builds and copies it to `~/Applications/Pulsebar.app` |
| `make test` | runs the unit tests |
| `make lint` | `swift format lint --strict` on the sources and tests |

> [!warning] Run tests through `make test`
> With only the Command Line Tools installed, plain `swift test` builds the tests and then silently runs **zero** of them, because SwiftPM can't find `Testing.framework` on its own. `make test` passes the framework search path and rpath.

Quit from the popover's **Quit** button (⌘Q while it is open).

## What the numbers mean

Pulsebar samples every 2 s. Rates (CPU per app, disk, network) are deltas between two samples, so they show `—` for the first 2 s.

### Menu bar

- **Dot**: the kernel's memory pressure level. Green = normal, yellow = warning, red = critical.
- **First %**: memory used (see below) as a share of physical RAM.
- **Second %**: total CPU busy time (user + system) across all cores.

### Memory

| Row | Meaning | Source |
| --- | --- | --- |
| Pressure | Normal / Warning / Critical | `kern.memorystatus_vm_pressure_level` |
| Available to apps | The kernel's "memory free %" | `kern.memorystatus_level` (same as `memory_pressure -Q`) |
| Used | App memory + Wired + Compressed, same as Activity Monitor | `host_statistics64(HOST_VM_INFO64)` |
| App memory | Anonymous pages minus purgeable pages | `internal_page_count − purgeable_count` |
| Wired | Memory the kernel can't page out | `wire_count` |
| Compressed | Physical memory the compressor occupies | `compressor_page_count` |
| Cached files | File-backed and purgeable pages that macOS can drop at any time | `external_page_count + purgeable_count` |
| Swap | Swap file usage | `vm.swapusage` |

> [!note] Why "Used" can be high while pressure is green
> **Used** counts what's taking up RAM right now. macOS tries to keep RAM full and compresses memory before it swaps, so a high Used % on its own isn't a problem.
>
> **Pressure** and **Available to apps** (`kern.memorystatus_level`) are the kernel's own view of how much memory it can still hand out. That includes cached files it can drop and memory it can still compress. This is the number behind Activity Monitor's pressure graph.
>
> If you see 80% used and 75% available at the same time, that's normal. Start worrying when the dot turns yellow or red, available drops low and swap keeps growing.

### Top memory

The six apps with the highest total **memory footprint** (`ri_phys_footprint`, the "Memory" column in Activity Monitor). This includes compressed memory, so it can differ from RSS in `ps`.

Processes are grouped into apps by their launch path:

- If the path is inside a `.app` bundle, the **outermost** bundle names the app. Firefox's `plugin-container.app` helpers count as **Firefox**, and Docker's `com.docker.sailor` counts as **Docker**.
- Otherwise the executable's file name is used: `node`, `bun`, `claude`.
- `×N` is the number of processes grouped into the app.

The launch path comes from `KERN_PROCARGS2` (the path that was exec'd, before symlinks are resolved). `proc_pidpath` is only a fallback, because it resolves symlinks. For example, `~/.local/bin/claude` would otherwise show up as its versioned target `2.1.296`.

> [!info] Only your own processes
> Pulsebar runs without root, so it can't read other users' or root processes (`WindowServer`, `kernel_task`, system daemons). It skips them silently, so these lists only cover your own apps.

### CPU

- **Total**: share of all CPU ticks that were user or system time since the last sample (`host_processor_info`). It should match the user + sys figures in `top`.
- **Per app**: CPU time used during the last interval (`ri_user_time + ri_system_time`). **100% = one full core**, so a busy app can go above 100%. Apps at 0% are hidden.

### Disk

- **Free**: available capacity of `/` "for important usage" (it counts purgeable space macOS can reclaim, like Finder does), out of the total. Refreshed every 30 s, because each lookup goes through the `CacheDelete` service.
- **Read / Write**: throughput summed over all `IOBlockStorageDriver` devices.

### Network

**Down / Up**: bytes/s summed over all non-loopback interfaces. Uses the 64-bit counters from `NET_RT_IFLIST2`. Note that traffic through a VPN `utun` interface also passes through the physical interface, so it can be counted twice.

## Layout

| Path | Contents |
| --- | --- |
| `Sources/PulsebarKit` | Pure logic (app grouping, rates, top-N ranking, memory math, CPU ticks, procargs parsing), the samplers and the `Stats` model |
| `Sources/Pulsebar` | SwiftUI `MenuBarExtra` app, popover and menu bar label |
| `Tests/PulsebarKitTests` | swift-testing tests for the pure logic |
| `Support/Info.plist` | Bundle metadata used by `make build` |
