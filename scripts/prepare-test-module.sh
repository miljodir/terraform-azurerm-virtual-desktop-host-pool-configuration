#!/usr/bin/env bash
set -euo pipefail

module_file=fslogix.tf
git_source='  source = "git::https://github.com/miljodir/terraform-azurerm-storage-account.git?ref=5ed25d43357e1130b2a94ebc9c796f74bbf8e049"'
local_source='  source = "./tests/fixtures/fslogix-module"'

if [[ ! -f "$module_file" || ! -f tests/fixtures/fslogix-module/main.tf ]]; then
  echo "Run this script from the root of a disposable checkout." >&2
  exit 1
fi

if ! awk '
  /^module "fslogix" \{$/ { module_count++; in_module = 1; next }
  in_module && /^}/ { in_module = 0; next }
  in_module && /^  source = "git::https:\/\/github\.com\/miljodir\/terraform-azurerm-storage-account\.git\?ref=5ed25d43357e1130b2a94ebc9c796f74bbf8e049"$/ { source_count++ }
  in_module && /^  version[[:space:]]*=/ { version_count++ }
  END { exit !(module_count == 1 && source_count == 1 && version_count == 0) }
' "$module_file"; then
  echo "Expected one fslogix module with the pinned storage-account Git source and no version in $module_file." >&2
  exit 1
fi

if [[ "$(grep -Fxc "$git_source" "$module_file" || true)" != 1 ]]; then
  echo "Expected the storage-account source to occur only in the fslogix module." >&2
  exit 1
fi

sed -i \
  -e 's|^  source = "git::https://github\.com/miljodir/terraform-azurerm-storage-account\.git?ref=5ed25d43357e1130b2a94ebc9c796f74bbf8e049"$|  source = "./tests/fixtures/fslogix-module"|' \
  "$module_file"

if ! awk '
  /^module "fslogix" \{$/ { module_count++; in_module = 1; next }
  in_module && /^}/ { in_module = 0; next }
  in_module && /^  source = "\.\/tests\/fixtures\/fslogix-module"$/ { source_count++ }
  in_module && /^  version[[:space:]]*=/ { version_count++ }
  END { exit !(module_count == 1 && source_count == 1 && version_count == 0) }
' "$module_file" ||
   [[ "$(grep -Fxc "$local_source" "$module_file" || true)" != 1 ||
      "$(grep -Fxc "$git_source" "$module_file" || true)" != 0 ]]; then
  echo "Could not verify local test-module substitution in $module_file." >&2
  exit 1
fi

echo "Configured the local test-only module stub in $module_file."
