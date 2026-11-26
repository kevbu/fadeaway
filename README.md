# FadeAway

macOS menu bar app that hides apps left in the background longer than a timeout.

- Default timeout plus per-app overrides (custom time or never hide)
- Pause, "Hide all others now", launch at login
- Needs no Accessibility permission

## Build

```bash
./build.sh           # builds build/FadeAway.app
./build.sh install   # also copies it to ~/Applications
```

Requires the Swift toolchain (Xcode command line tools) and macOS 13 or later.
