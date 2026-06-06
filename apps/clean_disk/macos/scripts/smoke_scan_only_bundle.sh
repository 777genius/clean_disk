#!/bin/sh
set -eu

usage() {
  echo "Usage: $0 [--allow-unsigned-presign] /path/to/Clean Disk.app"
}

fail() {
  echo "error: $1" >&2
  exit 1
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

allow_unsigned_presign=0

case "${1:-}" in
  --help | -h)
    usage
    exit 0
    ;;
  --allow-unsigned-presign)
    allow_unsigned_presign=1
    shift
    ;;
esac

if [ "$#" -ne 1 ]; then
  usage >&2
  exit 64
fi

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

set +e
helper_output="$("$helper_path" --scan-only-packaging-smoke 2>&1)"
helper_status="$?"
set -e

if [ "$helper_status" -eq 0 ]; then
  echo "scan-only macOS bundle smoke: passed"
  exit 0
fi

if [ "$allow_unsigned_presign" -eq 1 ]; then
  failures="$(printf '%s\n' "$helper_output" | awk '/^- /{ print substr($0, 3) }')"
  failure_count="$(printf '%s\n' "$failures" | awk 'NF { count += 1 } END { print count + 0 }')"
  if [ "$failure_count" -eq 1 ] && [ "$failures" = "unsigned_build" ]; then
    echo "scan-only macOS pre-sign bundle smoke: passed with expected unsigned_build"
    exit 0
  fi
fi

printf '%s\n' "$helper_output" >&2
fail "bundled helper scan-only packaging smoke failed"
