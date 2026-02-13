## Git conventions

- **Never commit directly to main/master.** Always create a feature branch and open a PR for changes.
- Keep commits atomic. Don't introduce something broken or incorrect and fix it in a follow-up commit within the same PR.
- PRs should preferably close a GitHub issue. Create an issue first if one doesn't exist, and reference it in the PR body (e.g., `Closes #123`).
- Do not include coding session URLs in commit messages.

## CI/CD

- Pipeline failures are **critical** and must be resolved before any other work proceeds.
- All tests must pass before a PR can be merged.
