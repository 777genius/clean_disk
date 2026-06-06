#!/bin/sh
set -eu

repo_root="$(cd "$SRCROOT/../../.." && pwd)"
configuration="${CONFIGURATION:-Debug}"

if [ -n "${CLEAN_DISK_SERVER_BINARY:-}" ]; then
  server_binary="$CLEAN_DISK_SERVER_BINARY"
elif [ "$configuration" = "Release" ]; then
  server_binary="$repo_root/target/release/clean-disk-server"
elif [ -x "$repo_root/target/debug/clean-disk-server" ]; then
  server_binary="$repo_root/target/debug/clean-disk-server"
else
  server_binary="$repo_root/target/release/clean-disk-server"
fi

if [ ! -x "$server_binary" ]; then
  if [ "$configuration" = "Release" ]; then
    echo "error: clean-disk-server helper is required for Release app bundles"
    echo "error: run cargo build --release -p clean-disk-server or set CLEAN_DISK_SERVER_BINARY"
    exit 1
  fi

  echo "warning: clean-disk-server helper was not bundled for $configuration"
  echo "warning: run cargo build -p clean-disk-server to enable local daemon packaging"
  exit 0
fi

contents_path="${CONTENTS_FOLDER_PATH:-$FULL_PRODUCT_NAME/Contents}"
helper_dir="$TARGET_BUILD_DIR/$contents_path/Helpers"
helper_path="$helper_dir/clean-disk-server"

mkdir -p "$helper_dir"
install -m 755 "$server_binary" "$helper_path"

if [ "${CODE_SIGNING_ALLOWED:-NO}" = "YES" ] && [ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]; then
  /usr/bin/codesign --force --sign "$EXPANDED_CODE_SIGN_IDENTITY" --options runtime "$helper_path"
elif [ "$configuration" = "Release" ]; then
  echo "error: Release helper must be code signed with the app"
  exit 1
else
  echo "warning: clean-disk-server helper was copied without explicit code signing"
fi

echo "Bundled clean-disk-server helper at $helper_path"
