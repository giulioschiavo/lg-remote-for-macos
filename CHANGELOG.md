# Changelog

## 1.0 — Initial launch / Lancio iniziale

- Default-off opt-in check for new GitHub Releases at startup and every 24 hours while the app is running.
- Manual update check remains available at any time.
- Available-release banner inside the app and a native notification when macOS notification permission is available.
- The release link opens only when the user chooses it; there is no automatic download or installation.
- Network requests go only to GitHub when the opt-in check is enabled or a manual check is started; no analytics or tracking requests are added.
- Version 1.0 is the launched build 14. The earlier 1.6 numbering was prelaunch and requires one manual replacement for users who installed it.

The v1.0 release is distributed as an arm64 ZIP. The update check never downloads or installs automatically.

## 1.6 — Prelaunch preparation / Preparazione prima del lancio

- English and Italian interface, including accessibility labels and app display name.
- Optional Magic Remote network pointer; buttons remain available when disabled.
- Four speed levels; the new 2× preserves the previous 4× movement multiplier.
- Native menu bar panel, volume, tuner channels, inputs, navigation and power commands.
- Local pairing in Keychain and configurable Wake-on-LAN.
- Relative touchpad restored after experimental centering/absolute mapping was removed.
- README in both languages, MIT license and compatibility reporting guidance.

This was a prelaunch build. It had no automatic update check; notarization, secure WebSocket transport and universal TV compatibility were not claimed.
