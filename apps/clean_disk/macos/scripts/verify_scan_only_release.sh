#!/bin/sh
set -eu

usage() {
  echo "Usage: $0 /path/to/Clean Disk.app"
}

fail() {
  echo "error: $1" >&2
  exit 1
}

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    fail "required tool is missing: $1"
  fi
}

canonical_path() {
  target="$1"
  if [ -d "$target" ]; then
    (cd "$target" && pwd -P)
  else
    dir="$(dirname "$target")"
    base="$(basename "$target")"
    (cd "$dir" && printf '%s/%s\n' "$(pwd -P)" "$base")
  fi
}

codesign_details() {
  target="$1"
  if ! details=$(/usr/bin/codesign -dv --verbose=4 "$target" 2>&1); then
    fail "codesign details failed for $target"
  fi
  printf '%s\n' "$details"
}

team_identifier() {
  printf '%s\n' "$1" | awk -F= '/^TeamIdentifier=/{ print $2; exit }'
}

require_distribution_signature() {
  label="$1"
  target="$2"
  details="$(codesign_details "$target")"
  team_id="$(team_identifier "$details")"

  if [ -z "$team_id" ] || [ "$team_id" = "not set" ]; then
    fail "$label is not signed with a real TeamIdentifier"
  fi
  if printf '%s\n' "$details" | grep -q '^Signature=adhoc$'; then
    fail "$label uses an ad-hoc signature"
  fi
  if ! printf '%s\n' "$details" | grep -q '^Authority=Developer ID Application:'; then
    fail "$label is not signed with Developer ID Application"
  fi
  if ! printf '%s\n' "$details" | grep -Eiq 'runtime|Runtime Version'; then
    fail "$label is missing hardened runtime evidence"
  fi

  printf '%s\n' "$team_id"
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

if [ "$#" -ne 1 ]; then
  usage >&2
  exit 64
fi

require_tool /usr/bin/codesign
require_tool /usr/sbin/spctl
require_tool /usr/bin/xcrun

app_path="$1"
[ -d "$app_path" ] || fail "app bundle does not exist: $app_path"
case "$app_path" in
  *.app) ;;
  *) fail "expected a .app bundle path" ;;
esac

app_path="$(canonical_path "$app_path")"
helper_path="$app_path/Contents/Helpers/clean-disk-server"
[ -x "$helper_path" ] || fail "bundled helper is missing or not executable: $helper_path"

helper_real="$(canonical_path "$helper_path")"
case "$helper_real" in
  "$app_path"/Contents/Helpers/clean-disk-server) ;;
  *) fail "helper is not inside the app bundle Helpers directory" ;;
esac

echo "Verifying code signatures"
if ! /usr/bin/codesign --verify --strict --deep --verbose=2 "$app_path" >/dev/null 2>&1; then
  fail "strict app bundle code signature verification failed"
fi
if ! /usr/bin/codesign --verify --strict --verbose=2 "$helper_path" >/dev/null 2>&1; then
  fail "strict helper code signature verification failed"
fi

app_team="$(require_distribution_signature "app bundle" "$app_path")"
helper_team="$(require_distribution_signature "clean-disk-server helper" "$helper_path")"
if [ "$app_team" != "$helper_team" ]; then
  fail "app and helper TeamIdentifier mismatch: $app_team != $helper_team"
fi

echo "Verifying Gatekeeper assessment"
if ! /usr/sbin/spctl --assess --type execute --verbose=4 "$app_path" >/dev/null 2>&1; then
  fail "Gatekeeper assessment failed"
fi

echo "Verifying stapled notarization ticket"
if ! /usr/bin/xcrun stapler validate "$app_path" >/dev/null 2>&1; then
  fail "stapled notarization ticket validation failed"
fi

echo "Running bundled helper scan-only smoke"
if ! "$helper_path" --scan-only-packaging-smoke >/dev/null 2>&1; then
  fail "bundled helper scan-only smoke failed"
fi

echo "scan-only macOS release gate: passed"
