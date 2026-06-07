#!/usr/bin/env bash
#
# build-csra.sh — build experimental CSRA (Companion Selective Repeat Ability)
# firmware with a distinguishing version label.
#
# Wraps the stock build.sh so you don't have to remember the env vars. The
# version label shows up both in the artifact filename and in the client app's
# device-info screen, so testers can tell a CSRA build from a stock release.
#
# These builds define -DCSRA_FORCE_SELECTIVE=1, which hard-enables Companion
# Selective Repeat (client_repeat=SELECTIVE) on every boot. That's needed because
# released client apps don't yet expose CMD_SET_CLIENT_REPEAT_MODE to turn it on.
#
# Usage:
#   ./build-csra.sh                       # build ALL companion devices (usb + ble)
#   ./build-csra.sh <env> [<env> ...]     # build only the named pio env(s)
#   ./build-csra.sh -v v1.16.0-csra2      # override the version label
#   CSRA_VERSION=v1.16.0-csra2 ./build-csra.sh
#
# Notes:
#   - build.sh appends "-<short-git-sha>" automatically, and the on-device
#     version field is capped at ~19 chars, so keep the label short.
#   - Artifacts land in ./out/  (build.sh wipes that dir at the start of a run).
#   - Do NOT push a "companion-*" git tag for these — that triggers the official
#     release workflow. Build locally with this script instead.

set -euo pipefail

cd "$(dirname "$0")"

# Default version label. Bump the suffix (csra1 -> csra2 ...) for each iteration
# you hand out, or override with -v / CSRA_VERSION.
VERSION="${CSRA_VERSION:-v1.16.0-csra1}"

# Parse an optional -v/--version flag; everything else is treated as pio env names.
TARGETS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -v|--version)
      VERSION="${2:?-v requires a version label}"
      shift 2
      ;;
    -h|--help)
      # print the leading comment block (lines after the shebang, up to the first blank/code line)
      awk 'NR>1 && /^#/ {sub(/^# ?/,""); print; next} NR>1 {exit}' "$0"
      exit 0
      ;;
    *)
      TARGETS+=("$1")
      shift
      ;;
  esac
done

if [[ ! -f build.sh ]]; then
  echo "error: build.sh not found; run this from the MeshCore repo root." >&2
  exit 1
fi

# Friendly heads-up if you're not on the CSRA branch (label still applies regardless).
branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
echo "Branch:  $branch"
echo "Version: $VERSION  (build.sh will append -<sha>)"

# Feeds straight into build.sh.
export FIRMWARE_VERSION="$VERSION"

# NOTE: deliberately NOT setting DISABLE_DEBUG=1. The official release pipeline
# doesn't either, so leaving it unset makes these builds identical to stock
# firmware except for the CSRA flag below -- the one variable we want to test.
# (It also avoids -UCFG_DEBUG, which breaks every nRF52 build; see build.sh.)

# Hard-enable Companion Selective Repeat in the firmware. build.sh appends to
# PLATFORMIO_BUILD_FLAGS, and PlatformIO applies this env to every build env, so
# the flag reaches all companion targets. Without it the CSRA code is inert and
# the feature can only be turned on via CMD_SET_CLIENT_REPEAT_MODE (not yet in
# released client apps). Keep this here, not in committed platformio.ini, so only
# CSRA builds carry it.
export PLATFORMIO_BUILD_FLAGS="${PLATFORMIO_BUILD_FLAGS:-} -DCSRA_FORCE_SELECTIVE=1"

if [[ ${#TARGETS[@]} -gt 0 ]]; then
  echo "Building: ${TARGETS[*]}"
  bash build.sh build-firmware "${TARGETS[@]}"
else
  echo "Building: all companion devices (*_companion_radio_usb + *_companion_radio_ble)"
  bash build.sh build-companion-firmwares
fi

echo
echo "Done. Artifacts in ./out/:"
ls -1 out/ 2>/dev/null || echo "  (none — check build output above)"
