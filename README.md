# LG Remote for macOS

[Italiano](README.it.md) · English

A small native macOS menu bar app to control an LG webOS TV on your local network.

I built this app for my own convenience: I wanted to adjust the volume, change channels and inputs, and navigate my TV without reaching for the remote. It turned out useful, so I’m happy to share it with anyone who might enjoy the same setup.

**Personal project by Giulio Schiavo. Tested on an LG 55UM7450PLA. Compatibility with every LG webOS TV is not guaranteed.**

## Preview

<img src="docs/images/lg-remote-en.png" alt="LG Remote for macOS in English" width="360">

English interface with sample data.

### App icons

| Light | Dark |
| --- | --- |
| <img src="LGRemote/Assets/AppIconLight.png" alt="LG Remote light icon" width="112"> | <img src="LGRemote/Assets/AppIconDark.png" alt="LG Remote dark icon" width="112"> |

## Features

- Menu bar remote with system light and dark appearance.
- Volume slider, volume buttons and mute.
- Previous/next channel and channel number entry for the TV tuner.
- Input selection, Home, Back, directional buttons and OK.
- Power off; Wake-on-LAN power on when supported and configured.
- Optional touchpad for the TV’s network pointer: move, click, scroll and right-click to go back.
- Four pointer speed levels. Disable **Magic Remote pointer** in Settings to use buttons only.
- Persistent pairing through macOS Keychain.
- English and Italian interface, following the app language selected by macOS: **LG Remote** / **Telecomando LG**.

## Requirements and compatibility

- A Mac with Apple Silicon and macOS 13 or later. The current build is arm64; Intel builds are not provided.
- An LG webOS TV with local network remote control available.
- Mac and TV on the same local network, without guest-network/client isolation.
- Approval of the pairing request on the TV at first connection.

The current implementation connects over `ws://<TV>:3000`. Encrypted `wss://` connections on port 3001 are not implemented yet. A TV that only accepts that transport will not connect with this version.

**Tested TV:** LG 55UM7450PLA. Basic remote commands and relative pointer movement were tested by the author. Wake-on-LAN is implemented but should be verified for your particular TV and network. No broader compatibility certification is claimed.

Pointer support depends on the TV’s network input service and permissions. Owning a physical Magic Remote is not an app requirement, and physical remote compatibility does not prove network pointer compatibility. If pointer control is unavailable, switch it off in Settings and try the directional buttons. Some TVs may also restrict those buttons because they use the network input service.

LG NetCast TVs, non-webOS TVs and external HDMI set-top boxes are outside the supported scope. Channel commands address the TV tuner, not an attached decoder. Some TV apps may not expose pointer interactions.

## Installation

Build the app from source using the instructions below. A packaged download will be added to [Releases](https://github.com/giulioschiavo/lg-remote-for-macos/releases) when available.

Current locally packaged builds are ad-hoc signed, **not Developer ID signed or notarized**. macOS may display an unverified-developer warning. Build from source if you prefer to inspect and compile the code. Developer ID signing and notarization are planned for easier distribution.

## First connection

1. Turn on the TV and open the app from Applications.
2. Open Settings and enter the TV’s hostname or IPv4 address. `LGwebOSTV.local` is the default, but it may differ on your network.
3. Choose **Save and connect**, then approve the prompt on the TV.
4. Grant local network access if macOS asks.

Pairing is saved in Keychain, so you normally only approve once. A TV reset, permission revocation or an expanded permission request can require pairing again. Use **Pair again** in Settings when needed.

Click the menu bar icon to open or hide the panel. Escape and clicking outside also hide it.

## Touchpad

Move the Mac cursor inside the touchpad to move the TV pointer relatively. Click to select, scroll with two fingers or a mouse wheel, and right-click to go back. Movement stops outside the touchpad; reenter to continue from the TV pointer’s current position.

The touchpad **does not map its edges to the screen**, warp the Mac cursor or automatically center the TV pointer. The TV can apply speed-dependent movement, so travel distance can vary. Change pointer speed in Settings, or disable the pointer and use buttons.

## Wake-on-LAN

1. On the TV, enable **Mobile TV On / TV On With Mobile → Turn on via Wi-Fi**, if available. Labels and paths vary with webOS version.
2. Enter the MAC address of the TV’s active Wi-Fi or Ethernet adapter in Settings. Do not use its AirPlay device identifier.
3. Set the subnet’s broadcast address. `192.168.1.255` is only appropriate for a `192.168.1.x` network with a `255.255.255.0` mask.
4. Save, put the TV in standby and try **Turn On**.

The TV must stay powered and its network hardware must support wake from standby. The app sends a local Wake-on-LAN packet; it does not offer wake over the internet, and sending a packet does not guarantee the TV has turned on.

## Privacy

TV commands and Wake-on-LAN traffic stay on the local network. The app has no analytics, ads, cloud account or tracking SDK. Pairing keys are stored in Keychain; TV address, wake settings and pointer preferences use local macOS preferences. Keys are not embedded in the app or repository.

There is **no automatic update check in this version**. A future opt-in check against GitHub Releases is planned; that would make an internet request to GitHub and will be documented when implemented.

## Build from source

Install Apple Command Line Tools and use a compatible Swift compiler:

```sh
xcode-select --install
cd LGRemote
./build.command
./dist/Telecomando\ LG.app/Contents/MacOS/LGRemote --self-test
open "dist/Telecomando LG.app"
```

The project uses SwiftUI, AppKit, Foundation and Security. No Node.js, Python or third-party package is needed to build the app. Python is only used by the optional icon packaging script. The build script produces an arm64 app and applies an ad-hoc signature. It does not install background services.

The checked-in PNG/ICNS assets include light and dark icon artwork. Menu bar artwork is a monochrome template. System Finder icon appearance variants are not claimed; the runtime app icon follows appearance.

## Feedback and contributions

Bug reports, pull requests and compatibility reports are welcome. Please include your TV model, webOS/firmware version, macOS version, app version and which commands work. Do not post pairing keys, private network details or full unredacted logs.

See [CONTRIBUTING.md](CONTRIBUTING.md) and [CHANGELOG.md](CHANGELOG.md). This is a spare-time project, so support and release timing are best effort.

## Roadmap

- Broader real-device compatibility testing.
- Secure WebSocket transport and improved TV discovery.
- GitHub Releases update checks, without silent installation.
- Developer ID signing/notarization and potential Intel builds.

## License and credits

[MIT License](LICENSE). Created by **Giulio Schiavo**, with AI-assisted development.

Independent, unofficial project. Not affiliated with, endorsed by or supported by LG Electronics. LG, webOS and Magic Remote are trademarks of their respective owners.
