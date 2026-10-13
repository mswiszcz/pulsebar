# Design contract

**THESIS**: The panel is a timeline, not a list of numbers. Four tracks share one 5-minute axis, so a spike in one metric lines up with the others. No stacked sections with a sparkline each.

**OWN-WORLD**: Native macOS. SF system font, monospaced digits, semantic system colors, one accent per track, SF Symbols. Light, dark and increased contrast. No cards, glass, decorative gradients or colored borders inside the panel. The one exception is the homelab server cards: separate windows hanging below the panel as one deck window, never inside it.

**STORY**: Open the panel and see at a glance whether memory pressure is a problem now and over the last 5 minutes, what CPU, disk and network are doing, and which app is the culprit. Click the culprit to open Activity Monitor.

**FIRST VIEWPORT**: About 425 pt wide, no scrolling. Pressure verdict header; Pressure, CPU, Disk and Network tracks with live values; Apps list; "Updated every 2 s" and the Activity Monitor, Settings and Quit glyph buttons. Homelab servers are not in the panel: each is a card hanging below it as a glimpse deck (30 pt strip with dot, name, CPU, RAM, VRAM, uptime); hovering a card opens it downward in full.

**FORM**: Aligned timeline tracks, candidate 7, seed key 3fe8761d.
