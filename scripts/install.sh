#!/bin/bash
# Installiert oder aktualisiert Pensum auf die neueste Version aus den GitHub-Releases.
# Was curl lädt, markiert macOS nicht als Download aus dem Internet, deshalb gibt es keine Gatekeeper-Warnung.
#
#   curl -fsSL https://raw.githubusercontent.com/maxikuehn/pensum/main/scripts/install.sh | bash
#
# Optional ein anderer Zielordner als /Applications, z. B. zum Ausprobieren: install.sh ~/Desktop/Test
set -euo pipefail

repo="maxikuehn/pensum"
target="${1:-/Applications}"
app="$target/Pensum.app"

release=$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest")
version=$(printf '%s' "$release" | sed -n 's/.*"tag_name": *"v\{0,1\}\([^"]*\)".*/\1/p' | head -n 1)
url=$(printf '%s' "$release" | sed -n 's/.*"browser_download_url": *"\([^"]*\.zip\)".*/\1/p' | head -n 1)
if [ -z "$url" ]; then
    echo "Kein Release mit ZIP gefunden." >&2
    exit 1
fi

if [ -d "$app" ]; then
    installed=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$app/Contents/Info.plist" 2>/dev/null || true)
    if [ "$installed" = "$version" ]; then
        echo "Pensum $version ist schon installiert."
        exit 0
    fi
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

echo "Lade Pensum $version …"
curl -fsSL "$url" -o "$work/Pensum.zip"
ditto -x -k "$work/Pensum.zip" "$work"
if [ "$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$work/Pensum.app/Contents/Info.plist")" != "de.maxikuehn.pensum" ]; then
    echo "Das Archiv enthält keine Pensum-App." >&2
    exit 1
fi

# Läuft Pensum aus dem Zielordner, wird es beendet und danach neu gestartet
was_running=false
if pgrep -f "$app/Contents/MacOS/Pensum" > /dev/null; then
    was_running=true
    osascript -e "tell application \"$app\" to quit" > /dev/null
    for _ in $(seq 1 20); do
        pgrep -f "$app/Contents/MacOS/Pensum" > /dev/null || break
        sleep 0.5
    done
fi

mkdir -p "$target"
rm -rf "$app"
ditto "$work/Pensum.app" "$app"
xattr -dr com.apple.quarantine "$app" 2> /dev/null || true

echo "Pensum $version ist installiert."
if $was_running || [ "$target" = "/Applications" ]; then
    open "$app"
fi
