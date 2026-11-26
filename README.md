# FadeAway

macOS menu bar app that hides apps left in the background longer than a timeout.

- Default timeout plus per-app overrides (custom time or never hide)
- App categories: mark each app as Work, Personal or Neutral (per-app submenu ▸ Category)
- Fast timeout: one global value (default 15 seconds) for apps the current mode hides faster
- Focus modes: a FadeAway Focus Filter sets the mode when a macOS Focus turns on
- Manual mode switch: menu ▸ Mode, for example "Presentation" right before a talk
- Pause, "Hide all others now", launch at login
- Needs no Accessibility permission

## Modes

| Mode | Work app | Personal app | Neutral app |
|---|---|---|---|
| Normal | own timeout | own timeout | own timeout |
| Work | own timeout | fast timeout | own timeout |
| Personal | fast timeout | own timeout | own timeout |
| Focus | fast timeout | fast timeout | fast timeout |
| Presentation | paused | paused | paused |

"Own timeout" is the per-app override if set, else the default timeout. The fast timeout never makes an app wait longer than its own timeout. An app set to "Never hide" never hides in any mode. Presentation pauses hiding without touching the "Pause hiding" switch.

## Focus Filter setup

1. Open the FadeAway menu ▸ Mode ▸ Set up Focus Filters… (or open System Settings ▸ Focus).
2. Choose a Focus, for example Work.
3. Under Focus Filters, click Add Filter and choose FadeAway.
4. Choose a Mode: Work, Personal, Focus or Presentation.

When that Focus turns on, FadeAway switches to the chosen mode. When it turns off, FadeAway returns to Normal. The menu shows the current mode, for example `Mode: Work (from Focus)`.

A pick in menu ▸ Mode overrides the Focus mode until you pick "Automatic (follow Focus)" or the Focus changes. The manual pick is not kept across restarts.

FadeAway must have been launched at least once before System Settings lists the filter.

## Build

```bash
./build.sh           # builds build/FadeAway.app
./build.sh install   # also copies it to ~/Applications
swift test           # runs the unit tests
```

FadeAway is a Swift Package. `build.sh` builds it with SwiftPM, then generates the App Intents metadata for the Focus Filter. That step needs Xcode (`xcode-select -p` must point to Xcode), not only the command line tools. Requires macOS 13 or later.

The Focus Filter needs a signature with a Team ID. `build.sh` signs with the first "Apple Development" identity in your keychain, or with `SIGN_IDENTITY` if set. A free Apple ID team in Xcode (Settings ▸ Accounts) is enough. Without an identity, `build.sh` signs ad-hoc and warns: the app runs, but System Settings keeps "Add" greyed out for the filter.
