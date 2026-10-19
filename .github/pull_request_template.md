## What and why

<!-- What does this change, and why? Link the issue it fixes, e.g. "Fixes #12". -->

## How it was tested

- [ ] `make test` (TimeConversionKit + app/widget tests)
- [ ] `make lint`
- [ ] Checked the widget in Notification Center or on the desktop (UI changes)
- [ ] `make site-test` (changes under `docs/`)

## Screenshots

<!-- For UI changes: before and after, light and dark if relevant. `make snapshots` renders every widget size into build/snapshots. -->

## Checklist

- [ ] User-visible changes are noted under **Unreleased** in `CHANGELOG.md`
- [ ] No network access, analytics or data collection added
- [ ] Time zone logic lives in `Packages/TimeConversionKit` and has tests
