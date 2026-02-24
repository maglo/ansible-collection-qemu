# Contributing to maglo.qemu

Contributions are welcome! This document covers how to set up a development environment, run tests, and submit changes.

## Prerequisites

- Python >= 3.9
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
ansible-test sanity --color -v
```

### Molecule tests

Molecule uses Docker by default. To use Podman instead, set `DRIVER` before running any `molecule` command:

```bash
export DRIVER=podman
```

Run all scenarios for a role:

```bash
cd roles/host
molecule test
```

```bash
cd roles/vms
molecule test
```

Run a specific scenario:

```bash
cd roles/host
molecule test -s novnc
```

### Manual testing

For end-to-end testing on real KVM hardware — required for VM lifecycle tests
(`started`, `restarted`, `absent`) and cloud-init seed ISO tests that cannot run in
containers — follow the [Manual Testing Guide](docs/docsite/rst/guide_manual_testing.rst).

## Git Workflow

- **Never commit directly to `main`.** Always create a feature branch and open a PR.
- PRs should close a GitHub issue. Create an issue first if one doesn't exist, and reference it in the PR body (e.g., `Closes #123`).
- Keep commits atomic — don't introduce something broken and fix it in a follow-up commit within the same PR.

## Adding a New Role

1. Create the role directory under `roles/<role_name>/` with at minimum:
   - `tasks/main.yml`
   - `defaults/main.yml`
   - `meta/main.yml` (with `galaxy_info` and `dependencies`)
   - `meta/argument_specs.yml` (for `ansible-doc` support and runtime validation)
   - `README.md`
2. Add Molecule tests under `roles/<role_name>/molecule/default/`.
3. Add the role to the CI matrix in `.github/workflows/ci.yml`.
4. Add the role to the table in the root `README.md`.

## Releasing

Only maintainers with push access to the repository can cut releases.

1. Ensure all planned changes are merged to `main` and CI is green.
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
   The `release` GitHub Actions workflow fires automatically and creates a GitHub Release
   with the tarball attached.

### Makefile

```bash
make build                   # build the collection tarball
make clean                   # remove built tarballs
make release VERSION=x.y.z  # compile changelog, bump version, build
make help                    # list all targets
```

## Reporting Issues

Open an issue on [GitHub](https://github.com/maglo/ansible-collection-qemu/issues) with a clear description and, if applicable, steps to reproduce.
