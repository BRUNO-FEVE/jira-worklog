#!/bin/sh
# WorklogBar installer — builds from source on your machine, which avoids
# Gatekeeper quarantine entirely (no "unidentified developer" warning).
#
#   curl -fsSL https://raw.githubusercontent.com/BRUNO-FEVE/jira-worklog/main/install.sh | sh
set -e

if ! command -v swift >/dev/null 2>&1; then
    echo "WorklogBar needs the Swift toolchain to build. Install it with:"
    echo "    xcode-select --install"
    exit 1
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "→ Downloading WorklogBar source..."
curl -fsSL https://github.com/BRUNO-FEVE/jira-worklog/archive/refs/heads/main.tar.gz \
    | tar -xz -C "$TMP" --strip-components 1

cd "$TMP"
echo "→ Building (release, ~30s)..."
./make_app.sh >/dev/null

echo "→ Installing to /Applications..."
osascript -e 'quit app "WorklogBar"' 2>/dev/null || true
sleep 1
rm -rf /Applications/WorklogBar.app
cp -R build/WorklogBar.app /Applications/
open /Applications/WorklogBar.app

echo "✓ WorklogBar installed — look for the Jira icon in your menu bar."
echo "  Open it and add your Jira URL + API token under Settings."
