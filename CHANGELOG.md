# Changelog

All notable changes to IST to EST are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
The release workflow uses the section of a version as its GitHub release notes,
so keep headings in the form `## [x.y.z] - YYYY-MM-DD`.

## [Unreleased]

## [1.0.0] - 2026-10-19

First public release: a free macOS widget and converter for India Standard Time (IST) and US Eastern Time (EST/EDT).

### Added

- **IST to EST widget** for Notification Center and the desktop, in three sizes:
  - Small: India and New York digital clocks with the current time difference.
  - Medium: two analog World Clock–style faces (light by day, dark at night), the digital time and date for each city, and an offset badge.
  - Large: the clocks plus an 8-row hour-by-hour IST → ET table with a green dot during US working hours (9:00–18:00, Monday to Friday), and a footnote with the next daylight saving change.
- **IST to EST Digital widget**: large numerals with live seconds in small, medium and large sizes.
- Automatic EST/EDT handling from the macOS time zone database, with the correct abbreviation for every date. India is always shown as IST, not "GMT+5:30".
- Minute-by-minute WidgetKit timeline: 60 entries, then a reload, with offsets computed per minute so daylight saving switches appear on time.
- Companion app with a live widget preview (style and size picker), an interactive converter (date and time in either zone, swap direction, copy result) and step-by-step instructions for adding the widget.
- Light and dark appearance, and the 12- or 24-hour clock from the system's region settings.
- Universal app for Apple silicon and Intel, for macOS 14 Sonoma or later (also works on macOS 15 Sequoia and macOS 26 Tahoe).
- App Sandbox for the app and the widget extension. No network access, no analytics, no data collection.
- `TimeConversionKit` Swift package with the time zone logic and XCTest tests that also run on Linux.
- Snapshot tests that render every widget size in summer (EDT) and winter (EST), light and dark.
- Website with an online IST ⇄ EST converter, a 24-hour conversion table and an FAQ: <https://surendrallam.github.io/ist-to-est-macos-widget/>.
- Release downloads with stable names: `IST-to-EST.dmg`, `IST-to-EST.zip` and `SHA256SUMS.txt`.

[Unreleased]: https://github.com/surendrallam/ist-to-est-macos-widget/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/surendrallam/ist-to-est-macos-widget/releases/tag/v1.0.0
