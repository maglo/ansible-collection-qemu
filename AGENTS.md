## Git conventions

- **Never commit directly to main/master.** Always create a feature branch and open a PR for changes.
- Keep commits atomic. Don't introduce something broken or incorrect and fix it in a follow-up commit within the same PR.
- PRs should preferably close a GitHub issue. Create an issue first if one doesn't exist, and reference it in the PR body (e.g., `Closes #123`).
- Do not include coding session URLs in commit messages.

## Issue labelling

Every issue **must** have at least one label applied when it is created. Use the labels below:

| Label | When to use |
|-------|-------------|
| `bug` | Something isn't working |
| `enhancement` | New feature or request |
| `documentation` | Improvements or additions to documentation |
| `ci` | CI/CD pipeline changes |
| `infrastructure` | Infrastructure and tooling |
| `testing` | Testing improvements |

An issue can have multiple labels (e.g. `documentation` + `ci` for a docs-linting CI job).

## CI/CD

- Pipeline failures are **critical** and must be resolved before any other work proceeds.
- All tests must pass before a PR can be merged.
- The `CI` gate job in `.github/workflows/ci.yml` **must pass** before merging any PR to `main`. This job aggregates all other CI jobs (lint, sanity, docs, molecule).

## Branch protection

- The `main` branch requires the **CI** status check to pass before merging.
- Direct pushes to `main` are not allowed; all changes must go through a pull request.
- Do not bypass or disable required status checks.

## Documentation

- Every new role **must** include a `README.md` covering its purpose, variables, dependencies, and an example playbook.
- When a new role is added, update the root `README.md` roles table, Quick Start section, and add an example playbook under `playbooks/`.
- When an existing role gains new features (variables, behaviour), update **both** the role `README.md` and the root `README.md` in the same PR.
- `CONTRIBUTING.md` must be kept in sync — new roles should appear in the Molecule tests section.

## Roles

- Every role variable used in tasks **must** be declared in `meta/argument_specs.yml` with correct type, description, and default.
- Per-VM dictionary keys (e.g. inside `create_vm_vms` items) must also be declared in the `options` block of the list variable's argument spec.
- Role `defaults/main.yml` and `meta/argument_specs.yml` must stay in sync — adding a default without a matching argument spec (or vice versa) will cause validation failures in CI.
