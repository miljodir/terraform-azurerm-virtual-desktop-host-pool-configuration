#!/usr/bin/env bash
set -euo pipefail

module_file=fslogix.tf
registry_source='  source  = "miljodir/storage-account/azurerm"'
local_source='  source  = "./tests/fixtures/fslogix-module"'
version_line='  version = "~> 1.12"'

if [[ ! -f "$module_file" || ! -f tests/fixtures/fslogix-module/main.tf ]]; then
  echo "Run this script from the root of a disposable checkout." >&2
  exit 1
fi

if [[ "$(grep -Fxc "$registry_source" "$module_file" || true)" != 1 ||
      "$(grep -Fxc "$version_line" "$module_file" || true)" != 1 ]]; then
  echo "Expected exactly one storage-account registry source and version in $module_file." >&2
  exit 1
fi

sed -i \
  -e 's|^  source  = "miljodir/storage-account/azurerm"$|  source  = "./tests/fixtures/fslogix-module"|' \
  -e '/^  version = "~> 1\.12"$/d' \
  "$module_file"

if [[ "$(grep -Fxc "$local_source" "$module_file" || true)" != 1 ||
      "$(grep -Fxc "$version_line" "$module_file" || true)" != 0 ]]; then
  echo "Could not verify local test-module substitution in $module_file." >&2
  exit 1
fi

echo "Configured the local test-only module stub in $module_file."
