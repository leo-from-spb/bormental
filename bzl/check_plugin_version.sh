#!/usr/bin/env bash
# Fails when plugin.xml and //bzl:plugin_version.bzl disagree about the plugin version.
set -euo pipefail

plugin_xml=$1
expected=$2

declared=$(sed -n 's:.*<version>\(.*\)</version>.*:\1:p' "$plugin_xml" | head -1)

if [[ "$declared" != "$expected" ]]; then
  echo "Version mismatch:" >&2
  echo "  $plugin_xml declares '$declared'" >&2
  echo "  bzl/plugin_version.bzl declares '$expected'" >&2
  exit 1
fi
