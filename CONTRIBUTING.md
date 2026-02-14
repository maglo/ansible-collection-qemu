# Contributing to basalt.qemu

Contributions are welcome! This document covers how to set up a development environment, run tests, and submit changes.

## Prerequisites

- Python >= 3.9
- Ansible >= 2.15
- Docker (for Molecule tests)
- Git

## Development Setup

Clone the repository:

```bash
git clone https://github.com/maglo/ansible-collection-qemu.git
cd ansible-collection-qemu
```

Install the required Python packages:

```bash
pip install ansible-core ansible-lint molecule molecule-plugins[docker]
```

## Running Tests

### Lint

```bash
ansible-lint
```

### Sanity tests

Sanity tests must run from within the expected collection path:

```bash
mkdir -p /tmp/collections/ansible_collections/basalt
ln -s "$(pwd)" /tmp/collections/ansible_collections/basalt/qemu
cd /tmp/collections/ansible_collections/basalt/qemu
ansible-test sanity --color -v
```

### Molecule tests

Run all scenarios for a role:

```bash
cd roles/qemu_host
molecule test
```

```bash
cd roles/create_vm
molecule test
```

Run a specific scenario:

```bash
cd roles/qemu_host
molecule test -s novnc
```

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

## Reporting Issues

Open an issue on [GitHub](https://github.com/maglo/ansible-collection-qemu/issues) with a clear description and, if applicable, steps to reproduce.
