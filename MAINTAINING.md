# Maintaining IST to EST

Notes for the maintainer: setting up the GitHub repository once, optional signing and notarization, cutting releases, and getting the website indexed by search engines. Contributor workflow (setup, tests, commit style) is in [CONTRIBUTING.md](CONTRIBUTING.md).

| | |
| --- | --- |
| Repository | <https://github.com/surendrallam/ist-to-est-macos-widget> |
| Website (GitHub Pages, from `docs/`) | <https://surendrallam.github.io/ist-to-est-macos-widget/> |
| Latest DMG | <https://github.com/surendrallam/ist-to-est-macos-widget/releases/latest/download/IST-to-EST.dmg> |
| Latest ZIP | <https://github.com/surendrallam/ist-to-est-macos-widget/releases/latest/download/IST-to-EST.zip> |
| Workflows | [CI](.github/workflows/ci.yml), [Pages](.github/workflows/pages.yml), [Release](.github/workflows/release.yml) |

## 1. One-time GitHub setup

### Create the repository and push

Create an **empty public** repository named `ist-to-est-macos-widget` under `surendrallam`, without a README, license or `.gitignore`, because the project already has them. Then push. With the [GitHub CLI](https://cli.github.com):

```sh
gh auth login
git add -A
git commit -m "feat: IST to EST 1.0.0"
git branch -M main
gh repo create surendrallam/ist-to-est-macos-widget --public --source . --remote origin --push
```

Without the CLI, create the repository on <https://github.com/new>, then:

```sh
git remote add origin https://github.com/surendrallam/ist-to-est-macos-widget.git
git push -u origin main
```

### Configure it

Run the setup script once. It needs `gh auth login` with admin rights on the repository, is safe to re-run, and `--dry-run` prints the commands without changing anything:

```sh
scripts/configure-github-repo.sh --dry-run   # preview
scripts/configure-github-repo.sh             # apply (defaults to surendrallam/ist-to-est-macos-widget)
```

It does the following:

- Makes the repository public, if it is not already.
- Sets the description to "Free macOS widget & converter for IST ⇄ EST/EDT — pin India time and US Eastern time to Notification Center, like World Clock."
- Sets the website to `https://surendrallam.github.io/ist-to-est-macos-widget/`.
- Replaces the topics with exactly: `macos`, `macos-widget`, `widgetkit`, `swiftui`, `swift`, `notification-center`, `world-clock`, `timezone`, `time-zone-converter`, `ist`, `est`, `edt`, `india`, `eastern-time`, `ist-to-est`, `mac-app`, `open-source`.
- Enables Issues and turns off the Wiki and Projects.
- Enables **GitHub Pages with GitHub Actions as the source**, which `pages.yml` needs.
- Enables **private vulnerability reporting** (used by [SECURITY.md](SECURITY.md) and [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)) and Dependabot alerts.

To do the same by hand instead:

| Setting | Where |
| --- | --- |
| Description, website, topics | Repository home page › gear icon next to **About** |
| Issues on, Wiki and Projects off | **Settings › General › Features** |
| Pages source | **Settings › Pages › Build and deployment › Source: GitHub Actions** |
| Private vulnerability reporting, Dependabot alerts | **Settings › Code security** (called **Advanced Security** on some accounts) › **Enable** for each |

There is no API for these, so do them by hand either way:

- **Social preview:** in **Settings › General › Social preview**, upload `docs/assets/og-image.png` (1200 × 630). This is the image shown when the repository link is shared.
- **Pin the repository** on your GitHub profile, so it shows up next to your name.

### Publish the website for the first time

The first push to `main` may run the Pages workflow before Pages is enabled, and that run fails. Once the setup script has run, start it again:

```sh
gh workflow run pages.yml
gh run watch
```

Or go to **Actions › Pages › Run workflow**. The workflow renders the widget screenshots on macOS, adds them to `docs/screenshots/`, removes `docs/tests/` and deploys `docs/`. If rendering fails, it reuses the screenshots that are already live. If it fails on the very first deploy, there is nothing to reuse, so the README and website images stay missing until a later render succeeds. After that, it runs on every push to `main` that touches `docs/`, `App/`, `Widget/`, `Shared/`, `Packages/`, `Tests/`, `project.yml` or the workflow itself.

### Recommended: protect `main`

In **Settings › Rules › Rulesets** (or **Branches**), require a pull request before merging, and require these status checks from the CI workflow:

- `Core tests (Linux)`
- `Core tests (macOS)`
- `App, widget & snapshot tests`
- `SwiftLint`
- `Website`
- `Workflows & scripts`

## 2. Signing and notarization (optional)

Without any secrets, the Release workflow builds an **ad-hoc signed** app that is not notarized. It works, but Gatekeeper blocks the first launch. The release notes then tell users to click **Open Anyway** in **System Settings › Privacy & Security**, or to run `xattr -dr com.apple.quarantine "/Applications/IST to EST.app"`.

With an [Apple Developer Program](https://developer.apple.com/programs/) membership, add these secrets in **Settings › Secrets and variables › Actions › New repository secret**. CI then signs with your Developer ID, notarizes and staples both the app and the DMG, and leaves the Gatekeeper note out of the release notes.

| Secret | Value |
| --- | --- |
| `MACOS_CERTIFICATE_P12_BASE64` | Your **Developer ID Application** certificate and its private key, exported as a `.p12` and base64-encoded. |
| `MACOS_CERTIFICATE_PASSWORD` | The password you chose when you exported the `.p12`. |
| `DEVELOPER_ID_APPLICATION` | Optional. The identity name, such as `Developer ID Application: NAME (TEAMID)`. When it is empty, the workflow finds it in the certificate. |
| `APPLE_ID` | The Apple Account email of the developer account, used for notarization. |
| `APPLE_TEAM_ID` | Your 10-character Team ID, from **developer.apple.com › Account › Membership details**. |
| `APPLE_APP_SPECIFIC_PASSWORD` | An app-specific password for that Apple Account. Create one at <https://account.apple.com> › **Sign-In and Security › App-Specific Passwords**. |

To create them:

1. **Certificate:** in Xcode, open **Settings › Accounts**, select your team, click **Manage Certificates…**, then **+ › Developer ID Application**. Only the Account Holder can create this type. You can also create it at **developer.apple.com › Certificates, Identifiers & Profiles**.
2. **Export:** in Keychain Access, open **My Certificates**, right-click **Developer ID Application: …**, choose **Export…**, save it as `DeveloperID.p12` and set a password.
3. **Upload** with the GitHub CLI, from the folder that holds the file:

   ```sh
   base64 -i DeveloperID.p12 | gh secret set MACOS_CERTIFICATE_P12_BASE64
   gh secret set MACOS_CERTIFICATE_PASSWORD         # prompts for the value
   gh secret set APPLE_ID
   gh secret set APPLE_TEAM_ID
   gh secret set APPLE_APP_SPECIFIC_PASSWORD
   # Optional: print the identity name for DEVELOPER_ID_APPLICATION
   security find-identity -v -p codesigning
   ```

4. Delete the exported `.p12` from your disk. The repository's `.gitignore` excludes `*.p12`, `*.p8` and `.env` files, but never commit signing material.

How the secrets combine:

| Secrets set | Result |
| --- | --- |
| None | Ad-hoc signed, not notarized; the release notes include the Gatekeeper steps |
| Certificate only | Developer ID signed, not notarized; Gatekeeper still blocks the first launch, and the notes still include the steps |
| Certificate and `APPLE_*` | Signed, notarized and stapled; opens without warnings |

Each run's summary shows the signing mode and whether the build was notarized.

**Signing locally.** `scripts/build-release.sh` (`make release`) reads the same environment variables. For notarization, it also accepts an App Store Connect API key as `NOTARY_KEY_PATH`, `NOTARY_KEY_ID` and `NOTARY_ISSUER_ID`, and `CODESIGN_KEYCHAIN` if the identity is not in your default keychain:

```sh
DEVELOPER_ID_APPLICATION="Developer ID Application: NAME (TEAMID)" \
NOTARY_KEY_PATH=~/keys/AuthKey_ABC123.p8 NOTARY_KEY_ID=ABC123 NOTARY_ISSUER_ID=<issuer-uuid> \
make release VERSION=1.1.0
```

Run `scripts/build-release.sh --help` for every option. Once releases are notarized, a Homebrew cask becomes possible (see the roadmap in the README).

## 3. Releasing

The Release workflow runs when a tag matching `v*.*.*` is pushed, or by hand from **Actions › Release › Run workflow** with a version. It runs the `TimeConversionKit` tests, imports the certificate if there is one, and runs `scripts/build-release.sh` to build the universal app. The script checks the bundle, signs and notarizes when it can, and writes `build/release/IST-to-EST.dmg`, `IST-to-EST.zip` and `SHA256SUMS.txt`. The workflow then publishes the GitHub release, with the matching `CHANGELOG.md` section as its notes. The asset names never change, so the `releases/latest/download/…` links in the README and on the website always point to the newest release.

### Checklist

- [ ] CI is green on `main`.
- [ ] `CHANGELOG.md`: rename `## [Unreleased]` to `## [X.Y.Z] - YYYY-MM-DD`, using that exact format, because the workflow looks for `## [X.Y.Z]`. Add a fresh `## [Unreleased]` above it, and update the link references at the bottom.
- [ ] `project.yml`: set `MARKETING_VERSION` to `"X.Y.Z"`. The workflow overrides it with the tag, but keep them equal.
- [ ] Website: update "Version X.Y.Z" in the download section of `docs/index.html` and `softwareVersion` in its SoftwareApplication JSON-LD. Then update the expected `softwareVersion` in `docs/tests/site.test.mjs`, run `make site-test`, and update `<lastmod>` in `docs/sitemap.xml`.
- [ ] Commit, tag and push:

  ```sh
  git commit -am "chore(release): vX.Y.Z"
  git tag -a vX.Y.Z -m "IST to EST X.Y.Z"
  git push origin main vX.Y.Z
  ```

- [ ] Watch the run with `gh run watch`, or in **Actions › Release**. Check the summary for the signing mode and notarization status.
- [ ] Check the release page: three assets (`IST-to-EST.dmg`, `IST-to-EST.zip`, `SHA256SUMS.txt`), the notes, and the Gatekeeper note if the build is not notarized.
- [ ] Smoke test on a Mac, using the public link:
  - [ ] Download `releases/latest/download/IST-to-EST.dmg` and verify it against `SHA256SUMS.txt`.
  - [ ] Install it, open it once (approve it in Privacy & Security if it is ad-hoc signed), and add the widget in all three sizes.
  - [ ] Confirm the app window shows the new version.
- [ ] Check that the Pages workflow deployed and that the website and README screenshots load.

If a release is broken, the simplest fix is a new patch release. Running the Release workflow by hand for a version that already exists replaces that release's assets and notes. However, the existing tag does not move, so do that only to rebuild the tagged commit: choose the tag itself under **Use workflow from**.

## 4. Search engines

The README, the repository description and topics, and the website are written to rank for searches such as "IST to EST", "IST to EST converter", "IST to EDT" and "IST to EST widget Mac". The website already has a canonical URL, a meta description, Open Graph and Twitter tags, JSON-LD (SoftwareApplication, WebSite, FAQPage) and `docs/sitemap.xml`.

A project site lives under a path (`/ist-to-est-macos-widget/`), so crawlers never read its `robots.txt`; that file only applies at the host root. Submit the sitemap to each search engine instead:

```text
https://surendrallam.github.io/ist-to-est-macos-widget/sitemap.xml
```

### Google Search Console

1. Open <https://search.google.com/search-console> and click **Add property**.
2. Choose **URL prefix** and enter `https://surendrallam.github.io/ist-to-est-macos-widget/`. A **Domain** property is not possible, because it needs DNS access to `github.io`.
3. Choose the **HTML tag** method. Copy the tag, for example `<meta name="google-site-verification" content="…">`, into the `<head>` of `docs/index.html` next to the other meta tags. Run `make site-test`, commit and push to `main`, wait for the Pages workflow to deploy, then click **Verify**. Keep the tag in place afterwards, because removing it un-verifies the property.
4. Under **Indexing › Sitemaps**, submit `https://surendrallam.github.io/ist-to-est-macos-widget/sitemap.xml`.
5. Under **URL inspection**, inspect the home page and click **Request indexing**.

### Bing Webmaster Tools

Bing's index also feeds DuckDuckGo, Yahoo and others.

1. Open <https://www.bing.com/webmasters> and sign in.
2. The quickest way is **Import from Google Search Console**, which brings over the verified property and its sitemap. Otherwise, add `https://surendrallam.github.io/ist-to-est-macos-widget/` by hand and choose the **HTML Meta Tag** method. Add `<meta name="msvalidate.01" content="…">` to the `<head>` of `docs/index.html`, deploy as above, and click **Verify**. For a site that lives under a path, the meta tag is more reliable than the XML file method, which expects a file at the site root.
3. Under **Sitemaps**, submit `https://surendrallam.github.io/ist-to-est-macos-widget/sitemap.xml`.
4. Optionally, use **URL Submission** for the home page.

### Ongoing

- Update `<lastmod>` in `docs/sitemap.xml` when the website content changes meaningfully.
- Keep the FAQ text and the FAQPage JSON-LD identical. `make site-test` checks this.
- Look at **Performance** in Search Console now and then, to see which queries bring visitors, and adjust the README and website wording to match.
- Publish GitHub releases with clear notes. Releases, stars and recent activity all help the repository rank in GitHub search.
