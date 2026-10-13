---
tags: [macos, menubar, swift]
---

# Pulsebar

A small native macOS menu bar utility that shows real system load: memory pressure, the apps using the most memory and CPU, disk and network throughput.

The menu bar shows a pressure dot, memory used % and total CPU %, e.g. `● 62% [cpu] 14%`. Click it to open the timeline panel.

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

Quit from the panel's **Quit** button (⌘Q while it is open).

## What the numbers mean

Pulsebar samples every 2 s. Rates (CPU per app, disk, network) are deltas between two samples, so they show `—` for the first 2 s.

### Menu bar

- **Dot**: the kernel's memory pressure level. Green = normal, yellow = warning, red = critical.
- **First %** (after the `memorychip` symbol): memory used (see below) as a share of physical RAM.
- **Second %** (after the `cpu` symbol): total CPU busy time (user + system) across all cores.
- Numbers are padded with figure spaces so the label keeps the same width as values change. The padding goes before each symbol, so every symbol stays next to its number.

## The panel

The panel is a timeline. Four tracks share one time axis covering the last 5 minutes (150 samples, 2 s apart). The newest sample is at the right edge, marked by a faint "now" line. Faint vertical ticks mark each minute, and a ruler under the tracks reads "5 min … now". A spike in one track lines up with what the other tracks were doing at that moment. History is kept in memory only, and the tracks start empty after launch and fill in from the right.

| Part | Shows |
| --- | --- |
| Header | Pressure verdict ("Memory: normal" / "under pressure" / "critical") with the level dot. On the right: memory **used %** (the same number as the menu bar) and swap used |
| Memory bar | Physical RAM split into App / Wired / Compressed / Cache / free (the empty part), with a legend in GB |
| Pressure track | Pressure % (100 − `kern.memorystatus_level`), colored by the pressure level at each sample, labeled "pressure" |
| CPU track | Total CPU busy %, labeled "all cores" |
| Disk track | Read above the center line, write mirrored below (lighter), with current R / W rates and free space on `/` |
| Network track | Down above the center line, up mirrored below, with current ↓ / ↑ rates |
| Apps | The top 6 apps by memory plus the top 3 by CPU, sorted by memory. Shows the app icon (a terminal symbol for non-bundle processes), `×N` processes, memory (GB with one decimal, MB as whole numbers) and CPU as a share of all cores (orange once an app uses more than one full core). CPU shows `—` until the second sample. Clicking a row opens Activity Monitor |

Each track is a single VoiceOver element. It reads the track name, the current value and the 5-minute min–max range. App rows read as "Docker, 8 processes, 5.8 GB memory, 2.3% CPU", with the hint "Opens Activity Monitor".

> [!note] Rate tracks use a square-root scale
> Disk and network tracks scale to the highest value in the window, but never below a floor: 1 MB/s for disk, 100 KB/s for network. That way 1–2 KB/s of idle chatter stays a sliver instead of filling the track. Read/write (or down/up) share one scale, and the current full-scale value is shown faintly at the top left of the graph. Heights are the square root of value ÷ full scale. On a linear scale, a single 50 MB/s burst flattens a steady 100 KB/s to a line on the baseline. A log scale makes idle noise look like activity and needs an arbitrary floor. Square root keeps spikes as the tallest marks but leaves the baseline activity visible.

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
> If you see 67% used and 17% pressure (83% available) at the same time, that's normal. Start worrying when the dot turns yellow or red, pressure climbs and swap keeps growing.

### Apps

App memory is the total **memory footprint** (`ri_phys_footprint`, the "Memory" column in Activity Monitor). This includes compressed memory, so it can differ from RSS in `ps`.

Processes are grouped into apps by their launch path:

- If the path is inside a `.app` bundle, the **outermost** bundle names the app. Firefox's `plugin-container.app` helpers count as **Firefox**, and Docker's `com.docker.sailor` counts as **Docker**.
- Otherwise the executable's file name is used: `node`, `bun`, `claude`.
- `×N` is the number of processes grouped into the app.

The launch path comes from `KERN_PROCARGS2` (the path that was exec'd, before symlinks are resolved). `proc_pidpath` is only a fallback, because it resolves symlinks. For example, `~/.local/bin/claude` would otherwise show up as its versioned target `2.1.296`.

> [!info] Only your own processes
> Pulsebar runs without root, so it can't read other users' or root processes (`WindowServer`, `kernel_task`, system daemons). It skips them silently, so these lists only cover your own apps.

### CPU

- **Total**: share of all CPU ticks that were user or system time since the last sample (`host_processor_info`). It should match the user + sys figures in `top`.
- **Per app** (Apps list): CPU time used during the last interval (`ri_user_time + ri_system_time`), divided by the number of logical cores. It's a share of the whole machine, comparable with Total: an app pinning one core on a 14-core Mac shows about 7%. An app joins the list for CPU only if it's above 0%.

### Disk

- **Free**: available capacity of `/` "for important usage" (it counts purgeable space macOS can reclaim, like Finder does), out of the total. Refreshed every 30 s, because each lookup goes through the `CacheDelete` service.
- **Read / Write**: throughput summed over all `IOBlockStorageDriver` devices.

### Network

**Down / Up**: bytes/s summed over all non-loopback interfaces. Uses the 64-bit counters from `NET_RT_IFLIST2`. Note that traffic through a VPN `utun` interface also passes through the physical interface, so it can be counted twice.

## Layout

| Path | Contents |
| --- | --- |
| `Sources/PulsebarKit` | Pure logic (app grouping, rates, app aggregation and culprit list, memory math, CPU ticks, procargs parsing, history ring buffer, track scale), the samplers and the `Stats` model |
| `Sources/Pulsebar` | SwiftUI `MenuBarExtra` app, timeline panel (tracks, memory composition, apps list) and menu bar label |
| `Tests/PulsebarKitTests` | swift-testing tests for the pure logic |
| `Support/Info.plist` | Bundle metadata used by `make build` |
| `docs/design-contract.md` | The approved design direction for the panel |
| `PRODUCT.md` | Product context: users, purpose, principles |
