## Git conventions

- **Never commit directly to main/master.** Always create a feature branch and open a PR for changes.
- **Before starting any work**, fetch from origin and rebase your branch on `origin/main`:
  ```bash
  git fetch origin
  git rebase origin/main
  ```
  Do not skip this step — unrebased branches cannot be merged.
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

The published documentation is <https://magnusloof.se/ansible-collection-qemu/>,
built from `docs/` by `.github/workflows/docs.yml`. The root `README.md` is the
landing page on GitHub and Ansible Galaxy: keep it short and let it point at
the site. Reference documentation belongs in the argument specs and the guides,
not in the README.

- Every new role **must** include a `README.md` covering its purpose, variables, dependencies, and an example playbook.
- When a new role is added, add it to the roles table in the root `README.md`, add an example playbook under `playbooks/`, and list that playbook in `docs/docsite/rst/guide_examples.rst`.
- When an existing role gains a user-visible feature, document it in the role `README.md` **and** in the relevant guide under `docs/docsite/rst/` in the same PR. Update the root `README.md` only when the summary it gives becomes wrong.
- Guides live in `docs/docsite/rst/`. A new guide needs a label of the form `.. _ansible_collections.maglo.qemu.docsite.<name>:`, an entry in `docs/docsite/extra-docs.yml`, and an entry in a toctree in `docs/site/index.rst`.
- Never edit or commit anything under `docs/site/collection/` — antsibull-docs generates it on every build.
- The site is built with `-W`, so a broken cross-reference fails the `docs` CI job. Run `docs/site/build.sh` (or `make docs`) before pushing a documentation change.
- `CONTRIBUTING.md` must be kept in sync — new roles should appear in the Molecule tests section.

## Roles

- Every role variable used in tasks **must** be declared in `meta/argument_specs.yml` with correct type, description, and default.
- Per-VM dictionary keys (e.g. inside `vms_list` items) must also be declared in the `options` block of the list variable's argument spec.
- Role `defaults/main.yml` and `meta/argument_specs.yml` must stay in sync — adding a default without a matching argument spec (or vice versa) will cause validation failures in CI.

## Releases

### Release checklist

1. Ensure all planned changes are merged to `main` and CI is green.
2. Run `make release VERSION=x.y.z`. This will:
   - Compile all changelog fragments into `CHANGELOG.rst` via `antsibull-changelog`.
   - Bump `version` in `galaxy.yml`.
   - Build the collection tarball.
3. Review the diff (`git diff`) and commit:
   ```
   git add CHANGELOG.rst changelogs/changelog.yaml galaxy.yml
   git commit -m "Release vX.Y.Z"
   ```
4. Open a PR for the release commit. Merge it.
5. Tag the release from `main`:
   ```bash
   git tag -a vX.Y.Z -m "Release vX.Y.Z"
   git push origin vX.Y.Z
   ```
6. The `.github/workflows/release.yml` workflow fires automatically, creates a GitHub
   Release, and attaches the tarball.

Publishing to Ansible Galaxy is automatic: `release.yml` ends with a "Publish to Ansible
Galaxy" step that runs `ansible-galaxy collection publish` on every `v*` tag, using the
`GALAXY_API_KEY` repository secret. To publish by hand, set `GALAXY_API_KEY` in the
environment and run `make publish`.

### Makefile targets

| Target    | Description                                                         |
|-----------|---------------------------------------------------------------------|
| `build`   | Build the collection tarball with `ansible-galaxy`                  |
| `clean`   | Remove built tarballs (`maglo-qemu-*.tar.gz`)                       |
| `release` | Compile changelog, bump version, build. Usage: `make release VERSION=x.y.z` |
| `publish` | Build, then publish to Galaxy with `GALAXY_API_KEY`                  |
| `docs`    | Build the documentation site into `docs/site/_build/html`            |

Run `make help` for a quick reference.

## Changelog

This project uses [antsibull-changelog](https://github.com/ansible-community/antsibull-changelog) to manage release notes via changelog fragments.

**Every PR that introduces a user-visible change must include a changelog fragment.**

- Place fragments in `changelogs/fragments/`.
- Name files `<pr-number>-<short-slug>.yaml` (e.g. `42-fix-validation.yaml`). Use a descriptive slug without a PR number for changes that span multiple commits.
- Fragment format:

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
  | `trivial` | CI, tooling, docs changes invisible to end users |
  | `release_summary` | One-line release headline (at most one per release) |

- A single fragment file may contain multiple keys.
- Lint your fragment before opening a PR: `antsibull-changelog lint`
- **Do not edit `CHANGELOG.rst` or `changelogs/changelog.yaml` directly.** Both files are managed by `antsibull-changelog`.
- At release time the maintainer runs `antsibull-changelog release --version X.Y.Z` to compile all fragments into `CHANGELOG.rst` and update `changelogs/changelog.yaml`.
