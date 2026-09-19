# Contributing to maglo.qemu

Contributions are welcome! This document covers how to set up a development environment, run tests, and submit changes.

## Prerequisites

- Python >= 3.9. Every CI job runs Python 3.12, so develop against 3.12 when you can.
- Ansible >= 2.15
- Docker or Podman (for Molecule tests)
- Git

## Development Setup

Clone the repository:

```bash
git clone https://github.com/maglo/ansible-collection-qemu.git
cd ansible-collection-qemu
```

Install the required Python packages:

```bash
# Docker (default):
pip install ansible-core ansible-lint molecule "molecule-plugins[docker]"

# Podman (alternative):
pip install ansible-core ansible-lint molecule "molecule-plugins[podman]"
```

## Running Tests

CI runs five jobs — lint, sanity, docs, molecule and changelog — and the `CI`
gate job aggregates them. That gate must pass before a PR can be merged, so run
the same commands locally first.

Each job runs only when the change can affect it. A `changes` job at the top of
`.github/workflows/ci.yml` compares the PR against its base branch and decides
which of the five to run; a change that touches only `CONTRIBUTING.md`, or a
release commit that touches only `CHANGELOG.rst`, `changelogs/changelog.yaml`
and `galaxy.yml`, does not run the molecule matrix. A job that is filtered out
shows as *skipped*, and the `CI` gate treats that as a pass — it always runs,
so the required status check always reports. Anything under `roles/`,
`playbooks/`, `meta/` or `plugins/`, and any change to the workflow itself,
runs everything. To force the full suite regardless, start the **CI** workflow
by hand from the Actions tab (`workflow_dispatch`).

### Lint

```bash
ansible-lint
```

### Sanity tests

Sanity tests must run from within the expected collection path:

```bash
mkdir -p /tmp/collections/ansible_collections/maglo
ln -s "$(pwd)" /tmp/collections/ansible_collections/maglo/qemu
cd /tmp/collections/ansible_collections/maglo/qemu
ansible-test sanity --color yes -v
```

CI runs this command against two ansible-core versions, `stable-2.16` and
`stable-2.17`. A change that needs a newer ansible-core breaks the `stable-2.16`
job.

### Docs

The docs job checks that every role has a `README.md`, that `ansible-doc` can
read each role argument spec, that the collection documentation passes the
antsibull-docs linter, and that the documentation site builds:

```bash
pip install ansible-core antsibull-docs

# Every role must have a README.md
ls roles/*/README.md

# Each role argument spec must be readable
mkdir -p /tmp/collections/ansible_collections/maglo
ln -s "$(pwd)" /tmp/collections/ansible_collections/maglo/qemu
ANSIBLE_COLLECTIONS_PATH=/tmp/collections ansible-doc -t role maglo.qemu.host
ANSIBLE_COLLECTIONS_PATH=/tmp/collections ansible-doc -t role maglo.qemu.vms

# Lint the collection docs, including docs/docsite/rst
antsibull-docs lint-collection-docs --plugin-docs /tmp/collections/ansible_collections/maglo/qemu
```

### Documentation site

<https://maglo.github.io/ansible-collection-qemu/> is built from this
repository by the `Docs site` workflow on every push to `main`, and the `docs`
CI job builds it on every PR. Build it locally the same way:

```bash
pip install -r docs/site/requirements.txt
docs/site/build.sh --serve   # http://localhost:8000
```

What lives where:

| Path | Contents |
|------|----------|
| `docs/docsite/rst/` | The guides, in reStructuredText. Ansible Galaxy renders these too |
| `docs/docsite/extra-docs.yml` | The order and grouping of the guides |
| `docs/site/index.rst` | The landing page |
| `docs/site/conf.py`, `docs/site/_static/` | Sphinx configuration and the theme tweaks |
| `docs/site/collection/` | **Generated.** The role reference and a copy of the guides — never edit, never commit |

The role reference is generated from `roles/*/meta/argument_specs.yml`, so a
new variable reaches the site through its argument spec. The narrative
documentation is hand-written: add a guide under `docs/docsite/rst/`, give it a
label of the form
`.. _ansible_collections.maglo.qemu.docsite.<name>:`, list it in
`docs/docsite/extra-docs.yml`, and add it to a toctree in `docs/site/index.rst`.

`sphinx-build` runs with `-W`, so a broken cross-reference or a malformed table
fails the build — and therefore CI.

### Changelog

```bash
pip install antsibull-changelog
antsibull-changelog lint
```

See [Changelog fragment](#changelog-fragment) below for what to add to a PR.

### Molecule tests

Molecule uses Docker by default. To use Podman instead, set `DRIVER` before running any `molecule` command:

```bash
export DRIVER=podman
```

Every scenario builds its container from
`geerlingguy/docker-rockylinux${EL_VERSION:-10}-ansible`, so `EL_VERSION`
selects the Enterprise Linux major version. It defaults to 10, and CI runs
every gated scenario on 10 alone: EL10 is the only supported host platform
since EL9 support was removed. The variable stays so that the next EL release
can be tried without editing nine `molecule.yml` files, and so that adding it
to the CI matrix is a one-line change.

Run all scenarios of a role. A bare `molecule test` runs the `default` scenario
only, so pass `--all`:

```bash
cd roles/host
molecule test --all
```

```bash
cd roles/vms
molecule test --all
```

```bash
cd roles/labview
molecule test --all
```

Run a specific scenario:

```bash
cd roles/vms
molecule test -s secureboot
```

The scenarios are:

| Role   | Scenario     | Gated by CI | What it covers |
|--------|--------------|-------------|----------------|
| `host` | `default`    | yes         | Packages, directories, `qemu-vm@.service` and `swtpm@.service` |
| `labview` | `default` | yes      | The console service: the account, the binary, the directory modes, the unit, the polkit rule, and that the running service serves the machine the `vms` role wrote |
| `vms`  | `default`    | yes         | Disk images, config files, UEFI NVRAM, TPM, networking |
| `vms`  | `disk_image` | **no**      | `disk_image_url` provisioning — it downloads a multi-gigabyte cloud image, so CI does not run it. Run it by hand before a release |
| `vms`  | `labview`    | yes         | `vms_labview_inventory_dir` — the per-machine console service inventory file, and its removal by `state: absent` |
| `vms`  | `lifecycle`  | yes         | `state: absent` with and without `force_destroy`. It creates a VM and then destroys it, so it cannot be idempotent; its `test_sequence` leaves out `idempotence` |
| `vms`  | `secureboot` | yes         | Secure Boot variable stores, `nvram_template`, `nvram_generation`, the NVRAM verification and the pre-0.4.0 upgrade path |

When you add a scenario, add it to the matrix in `.github/workflows/ci.yml` and
to this table. The matrix has two axes, `el_version` and `target`; add a
`{role: ..., scenario: ...}` entry to `target`. Do not move the scenarios into
`include:` — an `include:` entry is merged into every combination of the other
axes and a later entry overwrites an earlier one, so several entries setting
the same keys collapse into a single job.

### Manual testing

For end-to-end testing on real KVM hardware — required for the VM states that
boot a guest (`started`, `stopped`, `restarted`) and for tests that cannot run in
containers — follow the [Manual Testing Guide](docs/docsite/rst/guide_manual_testing.rst).

## Git Workflow

- **Never commit directly to `main`.** Always create a feature branch and open a PR.
- PRs should close a GitHub issue. Create an issue first if one doesn't exist, and reference it in the PR body (e.g., `Closes #123`).
- Keep commits atomic — don't introduce something broken and fix it in a follow-up commit within the same PR.

## Changelog fragment

**Every PR with a user-visible change must include a changelog fragment.** The
`changelog` CI job runs `antsibull-changelog lint`, and the `CI` gate job needs
it to pass.

- Put the fragment in `changelogs/fragments/`.
- Name it `<pr-number>-<short-slug>.yaml`, for example `42-fix-validation.yaml`.
  Use a descriptive slug without a PR number for a change that spans several
  commits.
- Format:

  ```yaml
  ---
  minor_changes:
    - "role_name - Description of the change (closes #N)."
  ```

- Valid top-level keys:

  | Key | When to use |
  |-----|-------------|
  | `major_changes` | Significant new functionality |
  | `minor_changes` | Small new features, enhancements |
  | `breaking_changes` | Backwards-incompatible changes |
  | `bugfixes` | Bug fixes |
  | `deprecated_features` | Features that will be removed |
  | `removed_features` | Features removed in this release |
  | `security_fixes` | Security-related fixes |
  | `trivial` | CI, tooling and docs changes that end users never see |
  | `release_summary` | One-line release headline (at most one per release) |

- One fragment file may hold several keys.
- Lint the fragment before you open the PR: `antsibull-changelog lint`
- **Do not edit `CHANGELOG.rst` or `changelogs/changelog.yaml` by hand.**
  `antsibull-changelog` writes both files at release time.

## Adding a New Role

1. Create the role directory under `roles/<role_name>/` with at minimum:
   - `tasks/main.yml`
   - `defaults/main.yml`
   - `meta/main.yml` (with `galaxy_info` and `dependencies`)
   - `meta/argument_specs.yml` (for `ansible-doc` support and runtime validation)
   - `README.md` covering the purpose, variables, dependencies and an example playbook
2. Add Molecule tests under `roles/<role_name>/molecule/default/`.
3. Add the role to the CI matrix in `.github/workflows/ci.yml`.
4. Add the role to the roles table in the root `README.md`.
5. Add an example playbook under `playbooks/`, and list it in
   `docs/docsite/rst/guide_examples.rst`.
6. Add the role and its scenarios to the [Molecule tests](#molecule-tests) table above.
7. Add a changelog fragment.

Every variable the role reads must be declared in `meta/argument_specs.yml` with
its type, description and default, and `defaults/main.yml` must agree with it.
CI fails when the two drift apart.

## Releasing

Only maintainers with push access to the repository can cut releases.

1. Ensure all planned changes are merged to `main` and CI is green. The release
   commit changes no role content, so its own CI run skips the molecule matrix
   — the code being released is what `main` was already tested with. Run the
   **CI** workflow by hand from the Actions tab if you want the full suite
   against the release commit anyway.
2. Run `make release VERSION=x.y.z`. This compiles changelog fragments, bumps the
   version in `galaxy.yml`, and builds the collection tarball.
3. Review the diff and commit:
   ```bash
   git diff
   git add CHANGELOG.rst changelogs/changelog.yaml galaxy.yml
   git commit -m "Release vX.Y.Z"
   ```
4. Open a PR for the release commit. Merge it.
5. Tag and push from `main`:
   ```bash
   git tag -a vX.Y.Z -m "Release vX.Y.Z"
   git push origin vX.Y.Z
   ```
   The `release` GitHub Actions workflow fires automatically. It builds the
   tarball, creates a GitHub Release with the tarball attached, and publishes the
   collection to Ansible Galaxy with `ansible-galaxy collection publish`. The
   publish step reads the `GALAXY_API_KEY` repository secret, so a tag releases
   to Galaxy as well.

### Makefile

```bash
make build                   # build the collection tarball
make clean                   # remove built tarballs
make release VERSION=x.y.z  # compile changelog, bump version, build
make publish                 # build, then publish to Galaxy (needs GALAXY_API_KEY)
make docs                    # build the documentation site into docs/site/_build/html
make help                    # list all targets
```

`make publish` is for a release by hand. The tag workflow already publishes, so
you rarely need it.

## Reporting Issues

Open an issue on [GitHub](https://github.com/maglo/ansible-collection-qemu/issues) with a clear description and, if applicable, steps to reproduce.
