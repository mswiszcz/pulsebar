Universal build (Apple Silicon and Intel), macOS 14 or later.

**Install:** unzip, move `Pulsebar.app` to `~/Applications` or `/Applications`, open it.

**First launch:** this build is ad-hoc signed, not notarized, so macOS blocks it the first time. Open **System Settings › Privacy & Security** and click **Open Anyway** next to Pulsebar, or run:

```sh
xattr -dr com.apple.quarantine ~/Applications/Pulsebar.app
```
