---
name: Pulsebar
description: Menu bar timeline of memory pressure, CPU, disk and network, with the apps behind them.
colors:
  pressure-normal: "#34C759"
  pressure-warning: "#FFCC00"
  pressure-critical: "#FF3B30"
  track-cpu: "#007AFF"
  track-disk: "#FF9500"
  track-network: "#30B0C7"
  label: "#000000D9"
  label-secondary: "#00000080"
  label-tertiary: "#00000042"
  fill-quaternary: "#0000001A"
  separator: "#0000001A"
typography:
  title:
    fontFamily: "SF Pro, -apple-system, system-ui, sans-serif"
    fontSize: "15px"
    fontWeight: 600
  body:
    fontFamily: "SF Pro, -apple-system, system-ui, sans-serif"
    fontSize: "13px"
    fontWeight: 400
    fontFeature: "tnum"
  value:
    fontFamily: "SF Pro, -apple-system, system-ui, sans-serif"
    fontSize: "12px"
    fontWeight: 400
    fontFeature: "tnum"
  label:
    fontFamily: "SF Pro, -apple-system, system-ui, sans-serif"
    fontSize: "10px"
    fontWeight: 400
  caption:
    fontFamily: "SF Pro, -apple-system, system-ui, sans-serif"
    fontSize: "10px"
    fontWeight: 400
    fontFeature: "tnum"
rounded:
  row: "6px"
spacing:
  hair: "3px"
  track: "6px"
  inner: "8px"
  section: "12px"
  panel: "14px"
components:
  popover:
    width: "425px"
    padding: "{spacing.panel}"
  track-row:
    height: "40px"
    typography: "{typography.value}"
  track-label:
    textColor: "{colors.label-secondary}"
    typography: "{typography.label}"
    width: "50px"
  track-value:
    textColor: "{colors.label}"
    typography: "{typography.value}"
    width: "84px"
  app-row:
    textColor: "{colors.label}"
    typography: "{typography.value}"
    padding: "3px 6px"
    rounded: "{rounded.row}"
  app-row-hover:
    backgroundColor: "{colors.fill-quaternary}"
    rounded: "{rounded.row}"
---

# Design System: Pulsebar

## Overview

**Creative North Star: "The Shared Axis"**

One 425 pt panel, read top to bottom as a verdict, then a timeline, then the culprits. Every metric is a track on the same 5-minute axis, so a spike in one lines up with the others. The world is native macOS and nothing else: SF Pro, monospaced digits, semantic system colors, SF Symbols, AppKit separators. Depth, chrome and decoration are left to the system window.

Density is high but quiet. Color is spent only on data: one accent per track, and the pressure color wherever pressure is shown. All chrome is gray.

**Key Characteristics:**
- Pressure verdict in plain words, before any number.
- Four tracks share column widths and time ticks; the newest sample is always at the right edge.
- Color means data. Text, rules and labels are semantic grays.
- Fixed width, no scrolling, no animation. Expanding an app row grows the panel downward.
- Light, dark and increased contrast come from system colors, not custom palettes.

## Colors

Semantic system colors only. Hex values are the light-appearance `NSColor` resolutions; the code names the system color, and dark and increased-contrast variants come from AppKit. See `.impeccable/design.json` for dark values.

### Primary
- **Pressure Green / Yellow / Red** (`systemGreen`, `systemYellow`, `systemRed`): kernel pressure level. Drives the header dot, the menu bar dot, the "App" segment of the composition bar, and the Pressure track, which recolors per sample so a past warning stays yellow in history.

### Secondary
- **CPU Blue** (`systemBlue`): CPU track only.
- **Disk Orange** (`systemOrange`): Disk track. Outside its track only as a per-app warning: the "busy app" CPU figure (semibold) and the growth badge.
- **Network Teal** (`systemTeal`): Network track only.

### Neutral
- **Label** (`labelColor`): primary values, app names, verdict.
- **Secondary Label** (`secondaryLabelColor`): track names, value captions ("pressure", "all cores", "1,2 TB free"), legends, process counts, idle CPU figures, footer.
- **Tertiary Label** (`tertiaryLabelColor`): currently on non-essential text; see Do's and Don'ts before reusing it for text.
- **Quaternary Fill** (`.quaternary`): composition bar track, app row hover.
- **Separator** (`separatorColor`): track baselines (100%), "now" edge (60%), minute ticks (35%), section dividers.
- **Primary at opacity**: memory composition grays — Wired 55%, Compressed 35%, Cache 18% of `.primary`.

### Named Rules
**The Color Is Data Rule.** A hue appears only where it encodes a metric or a pressure level. Chrome, labels and rules stay gray.

**The One Accent Per Track Rule.** Each track owns one system hue. A two-way track (read/write, down/up) uses the same hue for both halves, weighted by opacity, not a second color.

## Typography

**Display Font:** none
**Body Font:** SF Pro via SwiftUI text styles (`.title3`, `.body`, `.callout`, `.caption`, `.caption2`)
**Label/Mono Font:** SF Pro with `.monospacedDigit()`, not a mono family

**Character:** System text, one family, small sizes, hierarchy from weight and gray level rather than scale.

### Hierarchy
- **Title** (`.title3` semibold, ~15 pt): pressure verdict only ("Memory: normal").
- **Body** (`.body`, ~13 pt, tabular digits): "67% used" in the header.
- **Value** (`.callout`, ~12 pt, tabular digits): live track values, app rows. Shrinks to 85% before truncating.
- **Label** (`.caption`, ~10 pt): track names, Apps header, footer.
- **Caption** (`.caption2`, ~10 pt, tabular digits): value captions, legend, scale labels, ruler, R/W markers (semibold).

### Named Rules
**The Tabular Figures Rule.** Every changing number uses `.monospacedDigit()`. The menu bar label also pads with figure spaces (U+2007) to a fixed width so it never jitters.

**The Dash For Missing Rule.** Missing data renders as an em dash ("—"), never 0 or a spinner.

## Layout

Single fixed column, 425 pt wide, 14 pt padding, no scrolling. Vertical rhythm: 12 pt between sections, 8 pt inside the header group, 6 pt between tracks, 2 pt between app rows, 3 pt micro gaps.

Every track row is three columns: label (50 pt, leading), graph (flexible), value (84 pt, trailing), 8 pt gutters, 40 pt tall. The time ruler ("5 min" … "now") reuses the same column widths so it sits under the graphs. Minute ticks fall at 1–4 minutes ago (every 30 samples of a 150-sample buffer). History fills from the right; before 5 minutes elapse, the left of the plot is empty grid.

Single-direction tracks (Pressure, CPU) grow up from a bottom baseline. Two-way tracks (Disk, Network) mirror around a center baseline: read/down above, write/up below. Two-way tracks use a square-root scale with a floor (Disk 1 MB/s, Network 100 kB/s) and print their full-scale value.

Apps list: chevron (9 pt) · icon (16 pt) · name with "×N" process count · growth badge · memory (64 pt) · CPU (40 pt), right-aligned numeric columns, 6 pt row inset. Expanded detail lines are indented to the name column and share the memory and CPU columns.

Footer: "Updated every 2 s" left; `waveform.path.ecg.rectangle` borderless button (Activity Monitor, ⌘M), `gearshape` borderless button (Settings, ⌘,) and `power` borderless button (Quit, ⌘Q) right.

## Elevation & Depth

Flat. No shadows, materials, glass or gradients inside the panel; the only depth is the system `MenuBarExtra` window. Separation comes from `Divider()` rules and spacing. Area fills under graph lines are translucent tints of the track hue (28%, 50% under increased contrast), not shading.

### Named Rules
**The Window Is The Only Surface Rule.** No cards or inset panels inside the panel. Groups are separated by space and hairline dividers.

**Server cards.** Homelab servers are the one exception, and sit outside the panel: one window under it holding a deck of 30 pt glimpse strips (dot, name, CPU, RAM, VRAM, uptime), as wide as the panel, using the panel's own material, corner radius and outline, each 5 pt below the panel or the card above, with the system window shadow. Hovering a strip opens that card downward in place, pushing the others down; leaving closes it.

## Shapes

Rectangular and hairline. Graph rules are one device pixel. Graph lines are 1 pt with round joins. Corners appear only on the app row hover highlight (6 pt) and the composition bar (2 pt, 5 pt tall). Circles are reserved for status: pressure dot (10 pt header, 8 pt menu bar) and legend swatches (5 pt).

## Components

### Pressure Header
Dot in the pressure color, verdict in Title, then right-aligned "N% used" (secondary) over "Swap N" (caption2). Read as one accessibility element.

### Memory Composition Bar
5 pt bar on a quaternary track, 1 pt gaps: App (pressure color), Wired, Compressed, Cache (primary grays). Legend below in caption2 secondary with 5 pt dots; only the last item carries "GB".

### Track Row (signature)
- **Graph:** `Canvas`, line + translucent area per contiguous run; gaps (nil samples) break the line. Lower half of a two-way track is drawn at 55% emphasis.
- **Grid:** baseline, 4 minute ticks, right "now" edge, all from `separatorColor`.
- **Value column:** current value in Value style, caption beneath in secondary. Two-way tracks use Directional Values: a semibold secondary marker (letters "R"/"W" for disk, SF Symbol arrows for network) then the rate.
- **Accessibility:** one element per track; value reads current plus 5-minute range.

### App Row
Plain button, whole row clickable, toggles an inline disclosure; tooltip "Show processes" / "Hide processes". Leading `chevron.right` (9 pt semibold, secondary) points down when expanded; no rotation animation. Hover fills a 6 pt rounded quaternary background. App icon from the bundle, `terminal` SF Symbol for bundle-less processes. The name takes layout priority over the badge; "×N" never wraps. CPU above one core's share turns orange semibold, otherwise secondary. One app expanded at a time.

### App Details (expanded row)
- Indented to the name column, `.subheadline`, tabular digits, memory and CPU in the row's columns.
- Line: label, then "· uptime" in secondary (`3d`, `10h`). Label is the process role, the `~`-abbreviated working directory for bundle-less tools, or the container name for Docker (no uptime).
- States in secondary text, never a spinner: "Reading containers…", "Docker not reachable", "No running containers", "—" while details load.
- Last line: "Open in Activity Monitor", `.buttonStyle(.link)`.

### Growth Badge
`.caption`, `systemOrange`, beside the memory value on a collapsed or expanded row: "+1.2 GB / 10 min". Falls back to "+1.2 GB" when the row is too narrow (`ViewThatFits`). Orange here follows the busy-CPU precedent: a warning about one app, not chrome.

### Settings Window
SwiftUI `Settings` scene, `Form` with `.formStyle(.grouped)`, 420 pt wide, height fits content. Section 1: "Launch at login" toggle; when approval is needed, a secondary line "Approve in System Settings › General › Login Items" with an "Open Login Items" button; errors inline as a secondary `exclamationmark.triangle` label, and the toggle reverts to the real status. Section 2: "Notify when memory is under pressure" toggle and "Notify at" picker (Warning / Critical only), disabled while notifications are off.

### Menu Bar Label
Pressure dot (non-template 8 pt image, keeps its color), `memorychip` SF Symbol, memory %, `cpu` SF Symbol, CPU %. Symbols render monochrome (menu bar template tint); padding sits before each symbol. Whole percent, figure-space padded, tabular digits.

### Buttons
Borderless glyph buttons in the footer (`waveform.path.ecg.rectangle` Activity Monitor, `gearshape` Settings, `power` Quit), link-style "Open in Activity Monitor". No custom button styling.

## Do's and Don'ts

### Do:
- **Do** put every time series on the shared 5-minute axis with the 50 / flexible / 84 pt columns and 40 pt height.
- **Do** use system semantic colors and SwiftUI text styles so dark mode and increased contrast come free.
- **Do** give a new metric its own system hue and use it only in that track.
- **Do** use SF Symbols for icons (arrows, `memorychip`, `cpu`, `terminal`).
- **Do** use `.monospacedDigit()` on every changing number and "—" for missing data.
- **Do** keep text at secondary gray or stronger; legibility outranks quietness.

### Don't:
- **Don't** add cards, glass, materials, decorative gradients or colored borders.
- **Don't** give a track a sparkline-in-a-section layout; tracks align, they don't stack as separate widgets.
- **Don't** use a second hue for the other half of a two-way track.
- **Don't** use tertiary gray for text a user needs to read. The build still does (Swap line, scale labels, "5 min / now" ruler, Apps column headers); that is a known defect, not a style.
- **Don't** animate value or graph changes; the panel disables animations.
