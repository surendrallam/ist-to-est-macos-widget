# Security Policy

## Supported versions

Security fixes go into the latest release only. Please update to the [latest release](https://github.com/surendrallam/ist-to-est-macos-widget/releases/latest) before you report a problem.

| Version | Supported |
| --- | --- |
| 1.0.x (latest) | Yes |
| Older releases | No |

## Reporting a vulnerability

Please **do not open a public issue** for a security problem. Report it privately with GitHub's private vulnerability reporting:

1. Go to **[Report a vulnerability](https://github.com/surendrallam/ist-to-est-macos-widget/security/advisories/new)**. You can also go to the repository's **Security** tab and click **Report a vulnerability**.
2. Describe the problem, the affected version and macOS version, and the steps to reproduce it. Add a proof of concept if you have one.

Only you and the maintainer can see the report. The maintainer aims to acknowledge it within a week. Fixes are discussed and prepared in the private advisory and released as soon as practical. The advisory is then published, and you are credited unless you prefer not to be.

## Scope

IST to EST has a small attack surface by design:

- The app and its widget extension run in the **App Sandbox**. The only entitlement is `com.apple.security.app-sandbox`. Neither has the network client or server entitlement, so they cannot make or accept network connections.
- They access no user files, store no data, and use only the time zone database and region settings built into macOS. The app writes to the clipboard only when you click **Copy**.
- The website is static and served by GitHub Pages. It sets no cookies, has no third-party scripts and makes no requests to other sites. The converter runs entirely in your browser.

In scope, for example:

- A way for the app or widget to escape the sandbox, gain an entitlement or access data it should not.
- Problems with how release artifacts are built, signed, notarized or published (`scripts/build-release.sh`, `.github/workflows/release.yml`), or with the published checksums.
- Weaknesses in the GitHub Actions workflows, such as script injection or leaking secrets.
- Cross-site scripting or similar issues on the website, for example through the converter's URL parameters.

Out of scope:

- The Gatekeeper warning on first launch of an ad-hoc signed, non-notarized release. This is expected and [documented](README.md#if-macos-says-the-app-cant-be-opened).
- Attacks that need an already compromised Mac, administrator access or physical access.
- Vulnerabilities in macOS, Xcode, GitHub or other third-party services. Please report those to the vendor.
- Wrong times or time zone abbreviations. These are bugs, not security issues, so please [open an issue](https://github.com/surendrallam/ist-to-est-macos-widget/issues/new/choose).

## Verifying a download

Every release includes `SHA256SUMS.txt`. In the folder that holds the downloaded files, check it with:

```sh
shasum -a 256 -c SHA256SUMS.txt
```

You can inspect the signature of the installed app with:

```sh
codesign --verify --deep --strict --verbose=2 "/Applications/IST to EST.app"
codesign -d --entitlements - "/Applications/IST to EST.app"
spctl --assess --type execute --verbose=2 "/Applications/IST to EST.app"
```

`spctl` accepts the app only for releases that are signed with a Developer ID and notarized. Ad-hoc signed releases are rejected, which is expected for those builds.
