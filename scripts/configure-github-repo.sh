#!/usr/bin/env bash
#
# One-time maintainer setup of the GitHub repository with the gh CLI. Safe to re-run.
#
#   - makes the repository public
#   - sets the description, website and topics
#   - enables GitHub Pages, built by GitHub Actions (.github/workflows/pages.yml)
#   - enables private vulnerability reporting and Dependabot alerts
#   - enables issues; disables the wiki and projects
#
# Usage:  scripts/configure-github-repo.sh [--dry-run] [OWNER/REPO]
#         REPO=owner/name scripts/configure-github-repo.sh
#
# Needs `gh auth login` with admin rights on the repository.

set -euo pipefail

DEFAULT_REPO="surendrallam/ist-to-est-macos-widget"
DESCRIPTION="Free macOS widget & converter for IST ⇄ EST/EDT — pin India time and US Eastern time to Notification Center, like World Clock."
TOPICS=(
    macos macos-widget widgetkit swiftui swift notification-center world-clock
    timezone time-zone-converter ist est edt india eastern-time ist-to-est
    mac-app open-source
)

DRY_RUN=false
REPO_ARG=""
for arg in "$@"; do
    case "$arg" in
        -n | --dry-run) DRY_RUN=true ;;
        -h | --help)
            sed -n '3,15p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        -*)
            echo "Unknown option: $arg (see --help)" >&2
            exit 2
            ;;
        *) REPO_ARG="$arg" ;;
    esac
done

REPO="${REPO_ARG:-${REPO:-$DEFAULT_REPO}}"
[[ $REPO =~ ^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$ ]] || {
    echo "REPO must look like owner/name (got '$REPO')." >&2
    exit 2
}
OWNER="$(printf '%s' "${REPO%%/*}" | tr '[:upper:]' '[:lower:]')"
NAME="${REPO#*/}"
HOMEPAGE="https://${OWNER}.github.io/${NAME}/"

step() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

# Prints the command; runs it unless --dry-run.
run() {
    local arg line="+"
    for arg in "$@"; do
        case "$arg" in
            *\'*) line="$line $(printf '%q' "$arg")" ;;
            *[[:space:]\&\;\|\<\>\(\)\$\`\"\*\?\[]*) line="$line '$arg'" ;;
            *) line="$line $arg" ;;
        esac
    done
    printf '%s\n' "$line"
    if [[ $DRY_RUN == false ]]; then
        "$@"
    fi
}

command -v gh >/dev/null 2>&1 || {
    echo "The GitHub CLI is required: https://cli.github.com (brew install gh)" >&2
    exit 1
}
if [[ $DRY_RUN == false ]]; then
    gh auth status >/dev/null 2>&1 || {
        echo "Not signed in to GitHub. Run: gh auth login" >&2
        exit 1
    }
    gh repo view "$REPO" --json name >/dev/null || {
        echo "Cannot access $REPO. Check the name and your permissions." >&2
        exit 1
    }
fi

if [[ $DRY_RUN == true ]]; then
    echo "Configuring https://github.com/$REPO (dry run: printing commands, changing nothing)"
else
    echo "Configuring https://github.com/$REPO"
fi

step "Visibility: public"
visibility="unknown"
if [[ $DRY_RUN == false ]]; then
    visibility="$(gh repo view "$REPO" --json visibility --jq .visibility)"
fi
if [[ $visibility == PUBLIC ]]; then
    echo "Already public."
else
    run gh repo edit "$REPO" --visibility public --accept-visibility-change-consequences
fi

step "Description, website, issues/wiki/projects"
run gh repo edit "$REPO" \
    --description "$DESCRIPTION" \
    --homepage "$HOMEPAGE" \
    --enable-issues=true \
    --enable-wiki=false \
    --enable-projects=false

step "Topics (${#TOPICS[@]})"
# PUT replaces the whole list, so re-running never leaves stale topics behind.
topic_args=()
for topic in "${TOPICS[@]}"; do
    topic_args+=(-f "names[]=$topic")
done
run gh api --silent -X PUT "repos/$REPO/topics" "${topic_args[@]}"

step "GitHub Pages (source: GitHub Actions)"
if [[ $DRY_RUN == true ]]; then
    run gh api --silent -X POST "repos/$REPO/pages" -f build_type=workflow
elif output="$(gh api --silent -X POST "repos/$REPO/pages" -f build_type=workflow 2>&1)"; then
    echo "Enabled. The Pages workflow publishes $HOMEPAGE"
elif [[ $output == *"409"* ]]; then
    # Already enabled: make sure it builds from Actions rather than a branch.
    run gh api --silent -X PUT "repos/$REPO/pages" -f build_type=workflow
    echo "Already enabled; source set to GitHub Actions."
else
    echo "$output" >&2
    exit 1
fi

step "Private vulnerability reporting and Dependabot alerts"
run gh api --silent -X PUT "repos/$REPO/private-vulnerability-reporting"
run gh api --silent -X PUT "repos/$REPO/vulnerability-alerts"

step "Done"
cat <<EOF
Repository: https://github.com/$REPO
Website:    $HOMEPAGE

Manual steps that have no API:
  - Settings > General > Social preview: upload a 1280x640 image.
  - Optional release signing (Settings > Secrets and variables > Actions):
      MACOS_CERTIFICATE_P12_BASE64, MACOS_CERTIFICATE_PASSWORD, DEVELOPER_ID_APPLICATION,
      APPLE_ID, APPLE_TEAM_ID, APPLE_APP_SPECIFIC_PASSWORD
    Without them, releases are ad-hoc signed and users approve the app once on first launch.
EOF
