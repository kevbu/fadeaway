# FadeAway

macOS menu bar app (Swift, AppKit) that hides apps left in the background longer than a timeout. Swift Package: `Sources/FadeAway` (executable: AppKit app, Focus Filter intent), `Sources/FadeAwayCore` (library: pure, tested logic), `Tests/FadeAwayCoreTests`. Built with SwiftPM via `build.sh`, which also generates the App Intents metadata (needs Xcode, not only the command line tools). Settings live in `UserDefaults`. Needs no Accessibility permission. macOS 13+.

## Public repo rules

The GitHub repo is public. Everything committed is world-readable, this file included. Before every commit, merge or PR:

1. README: update `README.md` if the change touches features, menu items, settings, build steps or requirements.
2. Privacy check on the staged diff (`git diff --cached`): no personal names beyond the git author, no e-mail addresses, no absolute paths (`/Users/...`), no employer or client names, no tokens, keys, certificates or signing identities.
3. `.gitignore` is an allowlist. Do not add a `!` line for a new top-level path without asking. `_workflow/` stays local.
4. If the check finds something, stop and ask. Do not commit it and fix later: Git history stays public.

## Workflow Config

| Key | Value |
|-----|-------|
| workflow-dir | `_workflow` |
| test-cmd | `swift test` |
| lint-cmd | `swift format lint -r Sources Tests` |
| build-cmd | `./build.sh` |
| e2e-cmd | |
| e2e-framework | |
| tdd | `true` |
| branch-prefix | `feature/` |
| base-branch | `main` |
| worktree-layout | `standard` |

Notes:
- `lint-cmd` reports style warnings only and exits 0. Most come from swift-format's 2-space default versus the project's 4-space style. Do not treat them as failures. Do not reformat unrelated code.
- No e2e framework. Verify UI behavior manually by running `build/FadeAway.app`.
