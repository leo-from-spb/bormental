#!/usr/bin/env bash
#
# Builds the plugin and starts a locally installed IDE with it.
#
# The IDE runs in a sandbox: its own config, system, log and plugin directories under
# sandbox/, so the IDE you work in every day is not touched at all.
#
# Which IDE: $BORMENTAL_IDE_HOME when set (an IDE home or a macOS .app bundle),
# otherwise the first locally installed JetBrains IDE that is found.
#
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
repo=$PWD
bazel=${BAZEL:-bazel}

# --- the IDE to run ----------------------------------------------------------------

find_ide() {
    local candidate
    for candidate in "$HOME/Applications/JetBrains Toolbox/"*.app "$HOME/Applications/"*.app \
                     /Applications/*.app; do
        if [[ -f "$candidate/Contents/Resources/build.txt" ]]; then
            echo "$candidate"
            return 0
        fi
    done
    return 1
}

ide=${BORMENTAL_IDE_HOME:-}
if [[ -z "$ide" ]]; then
    ide=$(find_ide) || {
        echo "No locally installed IDE found. Set BORMENTAL_IDE_HOME to an IDE." >&2
        exit 1
    }
    echo "BORMENTAL_IDE_HOME is not set, using $ide"
fi

# Accept both an IDE home and a macOS .app bundle.
if [[ -d "$ide/Contents/lib" ]]; then
    ide_home="$ide/Contents"
elif [[ -d "$ide/lib" ]]; then
    ide_home="$ide"
else
    echo "$ide does not look like an IDE: no lib directory there." >&2
    exit 1
fi

if [[ -d "$ide_home/MacOS" ]]; then
    launcher=$(find "$ide_home/MacOS" -maxdepth 1 -type f -perm -u+x | head -1)
else
    launcher=$(find "$ide_home/bin" -maxdepth 1 -type f -name '*.sh' -perm -u+x | head -1)
fi
[[ -n "$launcher" ]] || { echo "No launcher found in $ide_home." >&2; exit 1; }

# The IDE reads its properties file from a product-specific variable: IDEA_PROPERTIES,
# DATAGRIP_PROPERTIES and so on. The prefix is the launcher name.
product=$(basename "$launcher" .sh)
properties_var="$(echo "$product" | tr '[:lower:]-' '[:upper:]_')_PROPERTIES"

# --- build -------------------------------------------------------------------------

"$bazel" build //:plugin
plugin_zip=$("$bazel" cquery //:plugin --output=files 2>/dev/null | tail -1)

# --- sandbox -----------------------------------------------------------------------

sandbox=$repo/sandbox
rm -rf "$sandbox/plugins"
mkdir -p "$sandbox/config" "$sandbox/system" "$sandbox/log" "$sandbox/plugins"
unzip -q "$plugin_zip" -d "$sandbox/plugins"

properties=$sandbox/idea.properties
cat >"$properties" <<EOF
idea.config.path=$sandbox/config
idea.system.path=$sandbox/system
idea.plugins.path=$sandbox/plugins
idea.log.path=$sandbox/log
idea.is.internal=true
EOF

build_txt=$ide_home/Resources/build.txt
[[ -f "$build_txt" ]] || build_txt=$ide_home/build.txt

echo "Starting $product ($(cat "$build_txt" 2>/dev/null || echo "unknown build"))"
echo "  plugin:  $plugin_zip"
echo "  sandbox: $sandbox"

export "$properties_var=$properties"
exec "$launcher" "$@"
