# Testing

This module is tested with the native [`terraform test`](https://developer.hashicorp.com/terraform/language/tests)
framework. The test suite also works with OpenTofu's `tofu test` command.
GitHub Actions runs both Terraform and OpenTofu on every pull request, regardless
of its target branch, on pushes to `main`, and on manual dispatch using a pinned shared workflow (see
`.github/workflows/terraform-test.yaml`).

## What runs in CI

| Job           | Command                                        | Purpose                                      |
| ------------- | ---------------------------------------------- | -------------------------------------------- |
| Format        | `terraform fmt -check -recursive`              | Consistent formatting                       |
| Validate      | `terraform init` + `terraform validate`        | Syntax, types and references are valid       |
| Test          | `terraform test`                               | Module behaviour (defaults, wiring, validation) |
| Fixture guard | `bash scripts/test-prepare-test-module.sh`     | Reject unexpected dependency source changes |

## How the tests work

- Test files live in `tests/` and end in `.tftest.hcl`.
- Every test file declares `mock_provider` blocks. Mocked providers never call
  Azure: no credentials are needed and **no real resources are created**.
  Resource attributes that Azure would compute (for example `id`) get generated
  fake values.
- Each `run` block plans (`command = plan`) or "applies" against the mocks
  (`command = apply`) with a set of input variables, then checks the result with
  `assert` blocks.
- Input validation is tested with `expect_failures`, which passes only when the
  listed variable validation or precondition fails.
- Data sources and nested modules that would need real lookups can be replaced
  with `override_data` / `override_module`.

- When tests run, the module is the *root* module. Terraform then rejects
  outputs that contain sensitive attributes unless they are marked
  `sensitive = true` (consumers calling the module are not affected). Put
  test-only override files in `tests/overrides/` named `*_override.tf`, e.g.

  ```hcl
  output "storage_account" {
    sensitive = true
  }
  ```

  CI copies them into the module root right before `terraform test`.

These are unit-style tests: they verify how the module turns inputs into
resource configuration. They do not prove that Azure accepts the configuration;
that still happens when a consuming workload runs `terraform plan`/`apply`.

## Testing without the registry module

The FSLogix test runs override outputs from the `miljodir/storage-account/azurerm`
child module, but `init` still downloads every declared module. To run these
tests without registry or GitHub SSH access, the shared workflow uses the
test-only stub in `tests/fixtures/fslogix-module`. It runs
`bash scripts/prepare-test-module.sh` before `init` in a disposable copy; the
script changes only that copy's `fslogix.tf` to point at the stub. Do not run it
in a working tree whose production files you need to preserve.

The stub declares the child module's inputs and empty outputs only; it does not
reproduce or validate the real child module's behavior or output contract.
Earlier trusted CI resolved the public registry dependency to 1.13.0 under the
existing `~> 1.12` constraint. Passing tests with this stub therefore verifies
the host-pool tests independently of that dependency, **not** compatibility
with or correctness of the real dependency. Tests that rely on the child's
outputs must continue to override them explicitly.

## Writing a test

```hcl
mock_provider "azurerm" {}

variables {
  resource_group_name = "rg-test"
}

run "defaults" {
  command = plan

  assert {
    condition     = azurerm_example.this.name == "expected"
    error_message = "Name should default to 'expected'."
  }
}

run "rejects_invalid_input" {
  command = plan

  variables {
    some_setting = "not-allowed"
  }

  expect_failures = [var.some_setting]
}
```

Guidelines:

- Add or update a test whenever you change behaviour, defaults or validation.
- Use obviously fake values (`rg-test`, `00000000-0000-0000-0000-000000000000`,
  documentation IP ranges such as `192.0.2.0/24`). Never use real subscription
  IDs, tenant IDs, names or addresses — this repository is public.
- Prefer one behaviour per `run` block with a descriptive name.

## Running locally

Requires Bash, Git, GNU `sed`, `grep`, `tar`, and `tee`, Terraform >= 1.7, and
OpenTofu 1.13.9 (the version used to verify this suite). The example uses Bash
features and a committed revision; it creates a fresh disposable copy for each
CLI, so initialization and the test-only module substitution cannot alter the
production checkout. On Windows, run it in Git Bash from Git for Windows, not
PowerShell or Command Prompt.

```bash
(
  set -euo pipefail
  tmp_root="$(mktemp -d)"
  trap 'rm -rf "$tmp_root"' EXIT

  mkdir "$tmp_root/terraform" "$tmp_root/opentofu"
  git archive HEAD | tar -x -C "$tmp_root/terraform"
  git archive HEAD | tar -x -C "$tmp_root/opentofu"

  filter='tests/host_pool.tftest.hcl'
  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) filter='tests\host_pool.tftest.hcl' ;;
  esac

  cd "$tmp_root/terraform"
  bash scripts/prepare-test-module.sh
  terraform init -backend=false
  terraform validate
  terraform test -no-color 2>&1 | tee terraform-test.log
  grep -Eq '^Success! [1-9][0-9]* passed' terraform-test.log
  terraform test -no-color "-filter=$filter" 2>&1 | tee terraform-filter.log
  grep -Eq '^Success! [1-9][0-9]* passed' terraform-filter.log

  cd "$tmp_root/opentofu"
  bash scripts/prepare-test-module.sh
  tofu init -backend=false
  tofu validate
  tofu test -no-color 2>&1 | tee tofu-test.log
  grep -Eq '^Success! [1-9][0-9]* passed' tofu-test.log
  tofu test -no-color "-filter=$filter" 2>&1 | tee tofu-filter.log
  grep -Eq '^Success! [1-9][0-9]* passed' tofu-filter.log
)
```

Terraform and OpenTofu support `-filter`. Use forward slashes on Unix-like
systems and backslashes on Windows; the example chooses the separator based on
the shell platform. It checks each full and filtered test command reports at
least one passing run, so an empty selection does not silently count as
success.

`git archive HEAD` includes committed files only. Commit the changes you want to
test before running this example. Do not run `scripts/prepare-test-module.sh`
in the production checkout: it changes `fslogix.tf` there to use a test-only
stub instead of the real module dependency. The temporary copies are removed
when the shell exits; this test suite has no copied output-override files to
clean up.

These commands need no Azure credentials. The stub avoids downloading the
private-transitive registry module in this fixture-backed test run, but does
not validate that real dependency's behavior or output contract.
