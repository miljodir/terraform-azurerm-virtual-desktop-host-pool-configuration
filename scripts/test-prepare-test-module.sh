#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

make_case() {
  local name="$1"
  local mutation="${2:-}"
  local case_dir="$tmp_root/$name"

  mkdir -p "$case_dir/scripts" "$case_dir/tests/fixtures/fslogix-module"
  cp "$repo_root/scripts/prepare-test-module.sh" "$case_dir/scripts/prepare-test-module.sh"
  cp "$repo_root/tests/fixtures/fslogix-module/main.tf" "$case_dir/tests/fixtures/fslogix-module/main.tf"
  cat > "$case_dir/fslogix.tf" <<'EOF'
module "fslogix" {
  for_each = local.fslogix

  source  = "miljodir/storage-account/azurerm"
  version = "~> 1.12"
}
EOF

  case "$mutation" in
    source)
      sed -i 's|miljodir/storage-account/azurerm|miljodir/storage-account/other|' "$case_dir/fslogix.tf"
      ;;
    version)
      sed -i 's|~> 1.12|~> 1.11|' "$case_dir/fslogix.tf"
      ;;
    target)
      sed -i 's/module "fslogix"/module "other"/' "$case_dir/fslogix.tf"
      ;;
    "")
      ;;
    *)
      echo "Unknown synthetic mutation: $mutation" >&2
      return 1
      ;;
  esac
}

make_case valid
(
  cd "$tmp_root/valid"
  bash scripts/prepare-test-module.sh
)
grep -Fqx '  source  = "./tests/fixtures/fslogix-module"' "$tmp_root/valid/fslogix.tf"
if grep -Fqx '  version = "~> 1.12"' "$tmp_root/valid/fslogix.tf"; then
  echo "The valid case retained the registry version constraint." >&2
  exit 1
fi
echo "PASS: expected source and version are replaced in a disposable copy."

for mutation in source version target; do
  make_case "$mutation" "$mutation"
  cp "$tmp_root/$mutation/fslogix.tf" "$tmp_root/$mutation/original.tf"
  if (cd "$tmp_root/$mutation" && bash scripts/prepare-test-module.sh) > "$tmp_root/$mutation.log" 2>&1; then
    echo "The preparation script accepted the changed $mutation." >&2
    exit 1
  fi
  if ! cmp -s "$tmp_root/$mutation/fslogix.tf" "$tmp_root/$mutation/original.tf"; then
    echo "The preparation script modified fslogix.tf after detecting changed $mutation." >&2
    exit 1
  fi
  echo "PASS: changed $mutation is rejected without modifying fslogix.tf."
done
