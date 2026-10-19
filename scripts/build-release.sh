#!/usr/bin/env bash
#
# Builds the distributable "IST to EST.app" (universal arm64 + x86_64), signs it,
# packages it, and writes into build/release/:
#
#   IST-to-EST.dmg    drag-to-Applications disk image
#   IST-to-EST.zip    the app, zipped with ditto
#   SHA256SUMS.txt    checksums of both
#
# Usage:  scripts/build-release.sh [VERSION [BUILD_NUMBER]]     (or `make release`)
#
# Environment (all optional):
#   VERSION                      Marketing version, e.g. 1.2.3. Default: the tag in
#                                GITHUB_REF_NAME (v1.2.3 -> 1.2.3), else MARKETING_VERSION
#                                from project.yml.
#   BUILD_NUMBER                 CFBundleVersion. Default: GITHUB_RUN_NUMBER, else 1.
#   DEVELOPER_ID_APPLICATION     Signing identity, e.g. "Developer ID Application: NAME (TEAMID)".
#                                Unset: the app stays ad-hoc signed (Gatekeeper will ask
#                                users to approve it on first launch).
#   CODESIGN_KEYCHAIN            Keychain that holds the identity (CI uses a temporary one).
#   Notarization (needs DEVELOPER_ID_APPLICATION), either:
#     APPLE_ID + APPLE_TEAM_ID + APPLE_APP_SPECIFIC_PASSWORD
#     NOTARY_KEY_PATH + NOTARY_KEY_ID + NOTARY_ISSUER_ID   (App Store Connect API key, .p8)
#
# Works from any directory. Requires macOS with Xcode and XcodeGen.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PROJECT="ISTtoEST.xcodeproj"
SCHEME="ISTtoEST"
APP_NAME="IST to EST"
APPEX_NAME="ISTtoESTWidget.appex"
APP_ENTITLEMENTS="App/ISTtoEST.entitlements"
APPEX_ENTITLEMENTS="Widget/ISTtoESTWidget.entitlements"
DERIVED_DATA="build/DerivedData"
RELEASE_DIR="build/release"
DMG_NAME="IST-to-EST.dmg"
ZIP_NAME="IST-to-EST.zip"
SUMS_NAME="SHA256SUMS.txt"

# --- helpers ----------------------------------------------------------------

info() { printf '\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die() {
    printf '\033[1;31merror:\033[0m %s\n' "$*" >&2
    if [[ ${GITHUB_ACTIONS:-} == true ]]; then echo "::error::$*"; fi
    exit 1
}

usage() {
    sed -n '3,26p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

require() {
    local tool
    for tool in "$@"; do
        command -v "$tool" >/dev/null 2>&1 || die "'$tool' is required but was not found."
    done
}

# Print one key of a bundle's Info.plist.
plist_value() {
    /usr/libexec/PlistBuddy -c "Print :$2" "$1/Contents/Info.plist"
}

# Fail unless the Mach-O binary contains both arm64 and x86_64 slices.
assert_universal() {
    local binary="$1" archs arch
    [[ -f $binary ]] || die "Missing binary: $binary"
    archs="$(lipo -archs "$binary")"
    for arch in arm64 x86_64; do
        [[ " $archs " == *" $arch "* ]] || die "$binary is not universal (architectures: $archs)."
    done
    echo "  $(basename "$binary"): $archs"
}

# sign <path> [entitlements]
sign() {
    local target="$1" entitlements="${2:-}"
    local args=(--force --sign "$SIGN_IDENTITY" --options runtime)
    if [[ $SIGNING == developer-id ]]; then
        args+=(--timestamp)
    else
        args+=(--timestamp=none)
    fi
    if [[ -n $entitlements ]]; then
        args+=(--entitlements "$entitlements")
    fi
    if [[ -n ${CODESIGN_KEYCHAIN:-} ]]; then
        args+=(--keychain "$CODESIGN_KEYCHAIN")
    fi
    codesign "${args[@]}" "$target"
}

# notarize <file>: submits a .zip or .dmg and waits for Apple's verdict.
notarize() {
    local file="$1" output status submission_id exit_code=0
    echo "Submitting $(basename "$file") to Apple's notary service (this usually takes a few minutes)…"
    output="$(xcrun notarytool submit "$file" "${NOTARY_ARGS[@]}" --wait --timeout 45m --output-format json)" ||
        exit_code=$?
    echo "$output"
    status="$(printf '%s' "$output" | sed -n 's/.*"status"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
    if [[ $exit_code -ne 0 || $status != Accepted ]]; then
        submission_id="$(printf '%s' "$output" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
        if [[ -n $submission_id ]]; then
            xcrun notarytool log "$submission_id" "${NOTARY_ARGS[@]}" >&2 || true
        fi
        die "Notarization of $(basename "$file") finished with status '${status:-unknown}'."
    fi
}

# --- arguments & configuration ------------------------------------------------

case "${1:-}" in
    -h | --help)
        usage
        exit 0
        ;;
    -*) die "Unknown option '$1'. Usage: scripts/build-release.sh [VERSION [BUILD_NUMBER]]" ;;
    *) ;;
esac

[[ $(uname -s) == Darwin ]] || die "Release builds need macOS with Xcode."

if [[ $# -ge 1 && -n $1 ]]; then VERSION="$1"; fi
if [[ $# -ge 2 && -n $2 ]]; then BUILD_NUMBER="$2"; fi

if [[ -z ${VERSION:-} ]]; then
    if [[ ${GITHUB_REF_NAME:-} =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        VERSION="${GITHUB_REF_NAME#v}"
    else
        VERSION="$(awk '/^[[:space:]]*MARKETING_VERSION:/ { v = $2; gsub(/["\047]/, "", v); print v; exit }' project.yml)"
    fi
fi
VERSION="${VERSION#v}"
BUILD_NUMBER="${BUILD_NUMBER:-${GITHUB_RUN_NUMBER:-1}}"

[[ $VERSION =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] ||
    die "VERSION must look like 1.2.3 (got '${VERSION}')."
[[ $BUILD_NUMBER =~ ^[0-9]+(\.[0-9]+){0,2}$ ]] ||
    die "BUILD_NUMBER must be a number like 42 (got '${BUILD_NUMBER}')."

if [[ -n ${DEVELOPER_ID_APPLICATION:-} ]]; then
    SIGNING="developer-id"
    SIGN_IDENTITY="$DEVELOPER_ID_APPLICATION"
else
    SIGNING="ad-hoc"
    SIGN_IDENTITY="-"
fi

NOTARY_ARGS=()
if [[ -n ${NOTARY_KEY_PATH:-} && -n ${NOTARY_KEY_ID:-} && -n ${NOTARY_ISSUER_ID:-} ]]; then
    NOTARY_ARGS=(--key "$NOTARY_KEY_PATH" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER_ID")
elif [[ -n ${APPLE_ID:-} && -n ${APPLE_TEAM_ID:-} && -n ${APPLE_APP_SPECIFIC_PASSWORD:-} ]]; then
    NOTARY_ARGS=(--apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APPLE_APP_SPECIFIC_PASSWORD")
fi

NOTARIZE=false
if [[ ${#NOTARY_ARGS[@]} -gt 0 ]]; then
    if [[ $SIGNING == developer-id ]]; then
        NOTARIZE=true
    else
        warn "Notarization credentials are set but DEVELOPER_ID_APPLICATION is not; ad-hoc builds cannot be notarized. Skipping notarization."
    fi
fi

require xcodegen xcodebuild codesign lipo hdiutil ditto shasum xcrun
if [[ $NOTARIZE == true && -n ${NOTARY_KEY_PATH:-} && ! -f $NOTARY_KEY_PATH ]]; then
    die "NOTARY_KEY_PATH does not exist: $NOTARY_KEY_PATH"
fi

STAGING="$(mktemp -d "${TMPDIR:-/tmp}/ist-to-est-release.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT

echo "IST to EST release build"
echo "  version:      $VERSION ($BUILD_NUMBER)"
echo "  signing:      $SIGNING${DEVELOPER_ID_APPLICATION:+ ($DEVELOPER_ID_APPLICATION)}"
echo "  notarization: $NOTARIZE"
echo "  Xcode:        $(xcodebuild -version | tr '\n' ' ')"

# --- build --------------------------------------------------------------------

info "Generating $PROJECT with XcodeGen"
xcodegen generate --spec project.yml
for file in "$APP_ENTITLEMENTS" "$APPEX_ENTITLEMENTS"; do
    [[ -f $file ]] || die "XcodeGen did not generate $file."
done

info "Building $SCHEME (Release, universal)"
rm -rf "$RELEASE_DIR" "$DERIVED_DATA/Build/Products/Release"
mkdir -p "$RELEASE_DIR"

build_cmd=(
    xcodebuild
    -project "$PROJECT"
    -scheme "$SCHEME"
    -configuration Release
    -destination "generic/platform=macOS"
    -derivedDataPath "$DERIVED_DATA"
    MARKETING_VERSION="$VERSION"
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER"
    ARCHS="arm64 x86_64"
    ONLY_ACTIVE_ARCH=NO
    clean build
)
if command -v xcbeautify >/dev/null 2>&1; then
    if [[ ${GITHUB_ACTIONS:-} == true ]]; then
        "${build_cmd[@]}" | xcbeautify --renderer github-actions
    else
        "${build_cmd[@]}" | xcbeautify
    fi
else
    "${build_cmd[@]}"
fi

# --- verify the bundle ----------------------------------------------------------

info "Checking the app bundle"
APP="$DERIVED_DATA/Build/Products/Release/$APP_NAME.app"
if [[ ! -d $APP ]]; then
    APP="$(find "$DERIVED_DATA/Build/Products" -maxdepth 2 -type d -name "$APP_NAME.app" | head -n 1)"
fi
[[ -n $APP && -d $APP ]] || die "Could not find \"$APP_NAME.app\" under $DERIVED_DATA/Build/Products."
APPEX="$APP/Contents/PlugIns/$APPEX_NAME"
[[ -d $APPEX ]] || die "The widget extension is missing: $APPEX"
echo "  app:    $APP"
echo "  widget: $APPEX"

built_version="$(plist_value "$APP" CFBundleShortVersionString)"
built_number="$(plist_value "$APP" CFBundleVersion)"
app_executable="$(plist_value "$APP" CFBundleExecutable)"
appex_executable="$(plist_value "$APPEX" CFBundleExecutable)"
extension_point="$(plist_value "$APPEX" NSExtension:NSExtensionPointIdentifier)"

[[ $built_version == "$VERSION" ]] || die "CFBundleShortVersionString is $built_version, expected $VERSION."
[[ $built_number == "$BUILD_NUMBER" ]] || die "CFBundleVersion is $built_number, expected $BUILD_NUMBER."
[[ $extension_point == com.apple.widgetkit-extension ]] ||
    die "$APPEX_NAME is not a WidgetKit extension (NSExtensionPointIdentifier: $extension_point)."

assert_universal "$APP/Contents/MacOS/$app_executable"
assert_universal "$APPEX/Contents/MacOS/$appex_executable"

# --- sign (inside-out) -------------------------------------------------------------

info "Signing ($SIGNING)"
if [[ -d $APP/Contents/Frameworks ]]; then
    while IFS= read -r -d '' nested; do
        sign "$nested"
    done < <(find "$APP/Contents/Frameworks" -depth \( -name '*.framework' -o -name '*.dylib' \) -print0)
fi
sign "$APPEX" "$APPEX_ENTITLEMENTS"
sign "$APP" "$APP_ENTITLEMENTS"

codesign --verify --deep --strict --verbose=2 "$APP"
for bundle in "$APPEX" "$APP"; do
    echo "Entitlements of $(basename "$bundle"):"
    entitlements="$(codesign -d --entitlements - "$bundle" 2>&1)"
    echo "$entitlements"
    [[ $entitlements == *com.apple.security.app-sandbox* ]] ||
        die "$(basename "$bundle") is not signed with the App Sandbox entitlement."
done
codesign -dvv "$APP" 2>&1 | grep -E '^(Identifier|Authority|TeamIdentifier|Runtime Version|Timestamp|Signature)=' || true

# --- notarize the app ----------------------------------------------------------------

if [[ $NOTARIZE == true ]]; then
    info "Notarizing the app"
    ditto -c -k --keepParent "$APP" "$STAGING/notarize-app.zip"
    notarize "$STAGING/notarize-app.zip"
    xcrun stapler staple "$APP"
    xcrun stapler validate "$APP"
fi

# --- disk image -------------------------------------------------------------------------

info "Creating $DMG_NAME"
DMG="$RELEASE_DIR/$DMG_NAME"
mkdir -p "$STAGING/dmg"
ditto "$APP" "$STAGING/dmg/$APP_NAME.app"
ln -s /Applications "$STAGING/dmg/Applications"
# hdiutil occasionally fails with "Resource busy" on CI machines; retry a few times.
for attempt in 1 2 3; do
    if hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING/dmg" -fs HFS+ \
        -format UDZO -imagekey zlib-level=9 -ov "$DMG"; then
        break
    fi
    [[ $attempt -lt 3 ]] || die "hdiutil create failed."
    warn "hdiutil create failed (attempt $attempt); retrying…"
    sleep $((attempt * 5))
done

if [[ $SIGNING == developer-id ]]; then
    sign_dmg_args=(--force --sign "$SIGN_IDENTITY" --timestamp)
    if [[ -n ${CODESIGN_KEYCHAIN:-} ]]; then
        sign_dmg_args+=(--keychain "$CODESIGN_KEYCHAIN")
    fi
    codesign "${sign_dmg_args[@]}" "$DMG"
    codesign --verify --verbose=2 "$DMG"
fi

if [[ $NOTARIZE == true ]]; then
    info "Notarizing the disk image"
    notarize "$DMG"
    xcrun stapler staple "$DMG"
    xcrun stapler validate "$DMG"
    spctl --assess --type execute --verbose=2 "$APP" || warn "spctl did not accept the app."
    spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG" ||
        warn "spctl did not accept the disk image."
fi

# --- zip & checksums -------------------------------------------------------------------

info "Creating $ZIP_NAME"
ditto -c -k --keepParent "$APP" "$RELEASE_DIR/$ZIP_NAME"

info "Writing $SUMS_NAME"
(cd "$RELEASE_DIR" && shasum -a 256 "$DMG_NAME" "$ZIP_NAME" >"$SUMS_NAME")
cat "$RELEASE_DIR/$SUMS_NAME"

# --- summary ------------------------------------------------------------------------------

if [[ $NOTARIZE == true ]]; then
    gatekeeper="notarized and stapled — opens without warnings"
elif [[ $SIGNING == developer-id ]]; then
    gatekeeper="Developer ID signed but NOT notarized — Gatekeeper will block first launch"
else
    gatekeeper="ad-hoc signed, NOT notarized — users must approve it once (Privacy & Security > Open Anyway)"
fi

info "Done"
echo "  version:    $VERSION ($BUILD_NUMBER)"
echo "  signing:    $SIGNING"
echo "  gatekeeper: $gatekeeper"
for file in "$DMG_NAME" "$ZIP_NAME" "$SUMS_NAME"; do
    printf '  %-15s %s\n' "$file" "$(du -h "$RELEASE_DIR/$file" | cut -f1)"
done
echo "  output:     $ROOT/$RELEASE_DIR"

if [[ -n ${GITHUB_OUTPUT:-} ]]; then
    {
        echo "version=$VERSION"
        echo "build-number=$BUILD_NUMBER"
        echo "signing=$SIGNING"
        echo "notarized=$NOTARIZE"
        echo "release-dir=$RELEASE_DIR"
    } >>"$GITHUB_OUTPUT"
fi
if [[ -n ${GITHUB_STEP_SUMMARY:-} ]]; then
    {
        echo "### IST to EST $VERSION ($BUILD_NUMBER)"
        echo
        echo "- Signing: **$SIGNING**"
        echo "- Notarized: **$NOTARIZE**"
        echo "- Gatekeeper: $gatekeeper"
        echo
        echo '```'
        cat "$RELEASE_DIR/$SUMS_NAME"
        echo '```'
    } >>"$GITHUB_STEP_SUMMARY"
fi
