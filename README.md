# IST to EST — Free macOS Widget & Converter

[![CI](https://img.shields.io/github/actions/workflow/status/surendrallam/ist-to-est-macos-widget/ci.yml?branch=main&label=CI)](https://github.com/surendrallam/ist-to-est-macos-widget/actions/workflows/ci.yml)
[![Latest release](https://img.shields.io/github/v/release/surendrallam/ist-to-est-macos-widget?sort=semver&label=release)](https://github.com/surendrallam/ist-to-est-macos-widget/releases/latest)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue)](LICENSE)
[![Platform: macOS 14+](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey?logo=apple)](#download--install)
[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-F05138?logo=swift&logoColor=white)](Packages/TimeConversionKit/Package.swift)

**IST to EST** is a free, open-source Mac widget that shows India Standard Time (IST) next to US Eastern Time (EST/EDT) in Notification Center or on your desktop, much like Apple's World Clock widget. It always applies the correct daylight saving offset, so you never have to work out whether New York is on EST or EDT. The companion app converts any date and time from India Standard Time to Eastern Time and back, and shows you how to add the widget. Everything runs on your Mac: no network access, no accounts, no tracking.

<p align="center">
  <a href="https://surendrallam.github.io/ist-to-est-macos-widget/">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://surendrallam.github.io/ist-to-est-macos-widget/screenshots/widget-medium-summer-dark.png">
      <img src="https://surendrallam.github.io/ist-to-est-macos-widget/screenshots/widget-medium-summer-light.png" width="412" alt="Medium IST to EST widget for macOS: two analog World Clock faces showing 9:30 PM IST in New Delhi and 12:00 PM EDT in New York, with a −9:30 offset badge between them">
    </picture>
  </a>
</p>

<p align="center">
  <a href="https://github.com/surendrallam/ist-to-est-macos-widget/releases/latest/download/IST-to-EST.dmg"><strong>Download for Mac (DMG)</strong></a>
  &nbsp;·&nbsp;
  <a href="https://surendrallam.github.io/ist-to-est-macos-widget/">Website and online IST ⇄ EST converter</a>
  &nbsp;·&nbsp;
  <a href="https://github.com/surendrallam/ist-to-est-macos-widget/releases">All releases</a>
</p>

## Contents

- [Features](#features)
- [Download & install](#download--install)
- [Add the widget to Notification Center](#add-the-widget-to-notification-center)
- [IST ⇄ EST quick reference](#ist--est-quick-reference)
- [Build from source](#build-from-source)
- [Project structure](#project-structure)
- [How it works](#how-it-works)
- [Privacy](#privacy)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [License](#license)

## Features

The widget comes in three sizes, for Notification Center or the desktop:

| Size | What it shows |
| --- | --- |
| Small | Two digital clocks, India on top and New York below, with the current gap (for example "9h 30m behind"). |
| Medium | Two analog faces in the style of World Clock (light by day, dark at night), the digital time and date for each city, and an offset badge such as `−9:30`. |
| Large | The clocks plus an hour-by-hour IST → ET table for the next 8 hours, starting at the current hour. A green dot marks US working hours (9:00–18:00, Monday to Friday). A footnote names the next daylight saving change, for example "ET switches to EST on Sun, Nov 1 · 10h 30m behind". |

- **A second widget style, "IST to EST Digital"**: large numerals with live seconds in all three sizes. The large size adds the gap between the cities and the next daylight saving change.

  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://surendrallam.github.io/ist-to-est-macos-widget/screenshots/digital-medium-summer-dark.png">
    <img src="https://surendrallam.github.io/ist-to-est-macos-widget/screenshots/digital-medium-summer-light.png" width="412" alt="Medium IST to EST Digital widget for macOS: large digital clocks with seconds showing 9:30:00 PM IST in New Delhi and 12:00:00 PM EDT in New York">
  </picture>

- **EST or EDT, always correct.** New York switches between EST (UTC−5) and EDT (UTC−4) on the right day, using the time zone database built into macOS. India stays on IST (UTC+5:30) all year.
- **Converter in the app.** Pick a date and time in either zone, swap the direction, and copy the result (⇧⌘C) as text, for example `9:30 PM IST (Tue, Jul 14) = 12:00 PM EDT (Tue, Jul 14)`.
- **Live widget preview** in the app window, for every style and size, plus step-by-step instructions for adding the widget.
- **Follows your Mac.** Light and dark appearance, and the 12- or 24-hour clock from your region settings.
- **Updates every minute** from a WidgetKit timeline. The app does not need to stay open.
- **Private and offline.** The app and widget are sandboxed, have no network access and collect nothing.
- **Native and universal.** SwiftUI and WidgetKit, one binary for Apple silicon and Intel.
- **Free and open source** under the MIT license.

## Download & install

**Requirements:** macOS 14 Sonoma or later (it also works on macOS 15 Sequoia and macOS 26 Tahoe), on Apple silicon or Intel.

1. Download **[IST-to-EST.dmg](https://github.com/surendrallam/ist-to-est-macos-widget/releases/latest/download/IST-to-EST.dmg)** from the latest release. A [ZIP](https://github.com/surendrallam/ist-to-est-macos-widget/releases/latest/download/IST-to-EST.zip) of the app is also available.
2. Open the disk image and drag **IST to EST** into **Applications**.
3. Open **IST to EST** from Applications once. This registers the widget with macOS. The app does not need to stay open afterwards.

### If macOS says the app can't be opened

Releases built without an Apple Developer ID certificate are ad-hoc signed and not notarized. The first time you open one, Gatekeeper blocks it with a message that Apple could not verify the app. The notes of such a release repeat these steps. You only need to do this once:

- Open **System Settings › Privacy & Security**, scroll down, click **Open Anyway** next to the message about IST to EST, and confirm, **or**
- remove the quarantine flag in Terminal:

  ```sh
  xattr -dr com.apple.quarantine "/Applications/IST to EST.app"
  ```

Releases that are signed with a Developer ID and notarized by Apple open without this step.

### Verify the download

Each release includes `SHA256SUMS.txt`. In the folder that holds the download:

```sh
curl -LO https://github.com/surendrallam/ist-to-est-macos-widget/releases/latest/download/SHA256SUMS.txt
grep 'IST-to-EST.dmg' SHA256SUMS.txt | shasum -a 256 -c -
```

The output should be `IST-to-EST.dmg: OK`. If you downloaded both the DMG and the ZIP, `shasum -a 256 -c SHA256SUMS.txt` checks both.

### Update or uninstall

To update, download the new DMG and replace the app in Applications. Widgets you already placed keep working.

To uninstall, remove the widget (right-click it › **Remove Widget**), quit the app and move `/Applications/IST to EST.app` to the Trash.

## Add the widget to Notification Center

1. Make sure **IST to EST** is in your **Applications** folder and that you have opened it once.
2. Click the date and time in the menu bar to open **Notification Center**.
3. Scroll to the bottom and click **Edit Widgets**.
4. Search for **IST to EST**. Choose the World Clock style (**IST to EST**) or **IST to EST Digital**.
5. Pick **Small**, **Medium** or **Large** and drag it into Notification Center, then click **Done**.

The same steps are shown in the app window, under **Add the widget**.

### Add it to the desktop

Drag the widget from the gallery onto the desktop in step 5, or right-click an empty part of the desktop, choose **Edit Widgets…** and drag **IST to EST** wherever you like. When windows cover the desktop, macOS can fade widgets to monochrome. To keep the colours, open **System Settings › Desktop & Dock** and set **Widget style** to **Full-color**.

### The widget is missing from the gallery

- Check that the app is in `/Applications` (not in Downloads or on the disk image) and open it once.
- If macOS blocked the app, follow [the Gatekeeper steps](#if-macos-says-the-app-cant-be-opened) first.
- Close and reopen the widget gallery. If it still does not appear, log out and back in.

More answers are in the [FAQ on the website](https://surendrallam.github.io/ist-to-est-macos-widget/#faq).

## IST ⇄ EST quick reference

India Standard Time is UTC+5:30 all year. US Eastern Time is EST (UTC−5) in winter and EDT (UTC−4) in summer, so the gap depends only on the season in the US.

| | US winter: EST | US summer: EDT |
| --- | --- | --- |
| Eastern Time offset | UTC−5 | UTC−4 |
| IST is ahead of New York by | 10 h 30 min | 9 h 30 min |
| IST → ET | subtract 10:30 | subtract 9:30 |
| ET → IST | add 10:30 | add 9:30 |
| In effect | first Sunday of November to second Sunday of March | second Sunday of March to first Sunday of November |

### Upcoming daylight saving changes

US clocks change at 2:00 AM local time:

| Change | New York | UTC | India (IST) | Gap afterwards |
| --- | --- | --- | --- | --- |
| EDT → EST (fall back) | Sun 1 Nov 2026, 2:00 AM EDT → 1:00 AM EST | 06:00 | 11:30 AM | 10 h 30 min |
| EST → EDT (spring forward) | Sun 14 Mar 2027, 2:00 AM EST → 3:00 AM EDT | 07:00 | 12:30 PM | 9 h 30 min |
| EDT → EST (fall back) | Sun 7 Nov 2027, 2:00 AM EDT → 1:00 AM EST | 06:00 | 11:30 AM | 10 h 30 min |

### Example conversions

| India (IST) | New York in winter (EST) | New York in summer (EDT) |
| --- | --- | --- |
| 9:00 AM | 10:30 PM, previous day | 11:30 PM, previous day |
| 6:30 PM | 8:00 AM | 9:00 AM |
| 7:30 PM | 9:00 AM | 10:00 AM |
| 9:30 PM | 11:00 AM | 12:00 PM (noon) |

Going the other way, 9:00 AM in New York is 7:30 PM IST in winter and 6:30 PM IST in summer, and 5:00 PM in New York is 3:30 AM (winter) or 2:30 AM (summer) the next day in India.

The website has [a converter](https://surendrallam.github.io/ist-to-est-macos-widget/#converter) and [a full 24-hour IST to EST/EDT table](https://surendrallam.github.io/ist-to-est-macos-widget/#time-table).

## Build from source

You do not need an Apple Developer account: builds are ad-hoc signed ("Sign to Run Locally").

### Prerequisites

- A Mac with **Xcode 16** or later
- [Homebrew](https://brew.sh), used by `make bootstrap` to install [XcodeGen](https://github.com/yonaskolb/XcodeGen), SwiftLint and xcbeautify from the [`Brewfile`](Brewfile)

```sh
git clone https://github.com/surendrallam/ist-to-est-macos-widget.git
cd ist-to-est-macos-widget

make bootstrap   # brew bundle: xcodegen, swiftlint, xcbeautify
make project     # generate ISTtoEST.xcodeproj from project.yml
make build       # Debug build into build/DerivedData
make test        # TimeConversionKit tests, then the app and widget tests
make install     # Release build, copied to /Applications and opened once
make snapshots   # render every widget size to PNG in build/snapshots
```

`ISTtoEST.xcodeproj` is generated by XcodeGen from [`project.yml`](project.yml) and is not committed. The same goes for `App/Info.plist`, `Widget/Info.plist` and both `.entitlements` files. After `make project`, open the project with `open ISTtoEST.xcodeproj` (or run `make xcode`), choose the **ISTtoEST** scheme and press ⌘R. Change build settings, targets and Info.plist keys in `project.yml`, not in Xcode, and run `make project` again after you add or remove files.

To try the widget itself, use `make install`. It copies the Release build to `/Applications`, removes the build-folder copies from Launch Services so the widget gallery does not list duplicates, and opens the app once.

| Target | What it does |
| --- | --- |
| `make` / `make help` | List all targets |
| `make bootstrap` | Install XcodeGen, SwiftLint and xcbeautify with Homebrew |
| `make project` / `make xcode` | Generate the Xcode project / generate and open it |
| `make build` / `make run` | Debug build / build and launch the app |
| `make test` | `test-core` (the Swift package) and `test-app` (Xcode test target) |
| `make snapshots` | Render `widget-{small,medium,large}-{summer,winter}-{light,dark}.png` (and the `digital-*` equivalents) into `build/snapshots` |
| `make lint` / `make lint-fix` | SwiftLint in strict mode / auto-correct, then lint |
| `make install` / `make uninstall` | Install into or remove from `/Applications` |
| `make release` | Universal DMG, ZIP and `SHA256SUMS.txt` in `build/release` (`make release VERSION=1.2.3`) |
| `make site` / `make site-test` | Serve `docs/` at <http://localhost:8000> / run the website tests |
| `make check` | Everything CI checks: lint, all tests, website tests |
| `make clean` / `make distclean` | Remove build output / also remove the generated project files |

The time zone logic can be tested without Xcode, on macOS or Linux (on Linux, install the `tzdata` package first):

```sh
swift test --package-path Packages/TimeConversionKit
```

## Project structure

```text
.
├── App/                          macOS app: live widget preview, converter, setup guide
│   ├── ISTtoESTApp.swift
│   ├── ContentView.swift
│   └── Assets.xcassets/          app icon and accent colour
├── Widget/                       WidgetKit extension (ISTtoESTWidget.appex)
│   ├── ClockWidget.swift         timeline provider and the two widgets
│   └── Assets.xcassets/
├── Shared/                       SwiftUI views used by the app, the widget and the tests
│   ├── ClockWidgetViews.swift    World Clock style: small, medium, large
│   ├── DigitalClockViews.swift   Digital style: small, medium, large
│   ├── AnalogClockView.swift     analog face, light by day and dark at night
│   ├── ClockStrings.swift        locale-aware 12/24-hour time strings
│   └── WidgetChrome.swift        widget sizes, background and preview card
├── Packages/TimeConversionKit/   Swift package with all time zone logic and its XCTest tests
├── Tests/ISTtoESTTests/          renders every widget in summer and winter, light and dark
├── docs/                         website on GitHub Pages: converter, table, FAQ
├── design/AppIcon.svg            source of the app and website icons (make icons)
├── scripts/                      release build, GitHub repo setup, icon and OG image rendering
├── .github/                      CI, Pages and Release workflows, issue and PR templates
├── project.yml                   XcodeGen spec for ISTtoEST.xcodeproj
├── Makefile                      developer tasks (make help)
├── Brewfile                      command-line tools for make bootstrap
└── package.json                  Node tooling for the website, icons and OG image
```

| Target | Type | Bundle identifier |
| --- | --- | --- |
| `ISTtoEST` | app, built as `IST to EST.app` | `io.github.surendrallam.ISTtoEST` |
| `ISTtoESTWidget` | app extension in `IST to EST.app/Contents/PlugIns/` | `io.github.surendrallam.ISTtoEST.Widget` |
| `ISTtoESTTests` | unit tests, no host app | `io.github.surendrallam.ISTtoEST.Tests` |

## How it works

- **TimeConversionKit** (`Packages/TimeConversionKit`) holds all of the time zone logic and has no UI code. `WorldZone` pairs an IANA zone (`Asia/Kolkata`, `America/New_York`) with its abbreviations. `ZoneTime` is the wall-clock reading of a zone at one instant. `TimeConverter` produces conversions, the offset between the zones, the hour-by-hour rows for the large widget and the next daylight saving change. Its tests run with `swift test` on macOS and Linux.
- **Shared SwiftUI views.** The widget, the live preview in the app and the snapshot tests all draw the same views from `Shared/`, so what you see in the app and in the screenshots is what the widget shows.
- **Minute-by-minute WidgetKit timeline.** The provider returns one entry for now and one for each of the next 59 minute boundaries, with the `.atEnd` reload policy, so WidgetKit asks for a fresh timeline after an hour. Each entry computes its own offsets, so a daylight saving switch inside that hour appears at the right minute. The Digital widget's seconds tick with a count-up `Text(timerInterval:)` that is re-anchored every minute, rather than one entry per second. Opening the app calls `WidgetCenter.shared.reloadAllTimelines()`.
- **Daylight saving from tzdata.** Offsets and transition dates come from `TimeZone` and the IANA time zone database that ships with macOS (the `tzdata` package on Linux). No dates are hard-coded, so a future change to US daylight saving rules arrives with a macOS update.
- **Abbreviation mapping.** Foundation reports `Asia/Kolkata` as "GMT+5:30" on Apple platforms instead of "IST". `WorldZone` therefore stores IST, EST, EDT and ET itself and picks EST or EDT with `isDaylightSavingTime(for:)`.
- **Sandboxed, no network.** The app and the widget extension are signed with the App Sandbox entitlement only. Without a network entitlement, they cannot open connections.

Screenshots in this README and on the website come from `Tests/ISTtoESTTests/WidgetSnapshotTests.swift`. It renders every size at 2026-07-14 21:30 IST (12:00 EDT) and 2026-01-15 09:00 IST (22:30 EST the day before), in light and dark mode. The [Pages workflow](.github/workflows/pages.yml) publishes the images under `https://surendrallam.github.io/ist-to-est-macos-widget/screenshots/`.

## Privacy

IST to EST collects no data. The app and widget make no network requests and contain no analytics. The website sets no cookies and loads nothing from third parties. See [PRIVACY.md](PRIVACY.md).

## Roadmap

These are ideas, not commitments. Open an issue if one of them matters to you.

- Other US time zones (Central, Mountain, Pacific) and other city pairs, chosen in the widget's settings
- A menu bar extra with both clocks and the converter
- Localisation of the app and widget
- A Homebrew cask, once releases are signed and notarized
- Configurable working hours for the large widget

## Contributing

Bug reports, ideas and pull requests are welcome. [CONTRIBUTING.md](CONTRIBUTING.md) explains how to set up the project, run the tests and open a pull request. Everyone taking part is expected to follow the [Code of Conduct](CODE_OF_CONDUCT.md). Please report security problems privately, as described in [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE) © 2026 surendrallam.

IST to EST is an independent project and is not affiliated with or endorsed by Apple. macOS, World Clock and Notification Center are names used by Apple Inc.
