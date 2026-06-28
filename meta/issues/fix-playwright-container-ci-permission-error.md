# Fix Playwright Container CI Permission Error

## Summary

The pushed docs-site Playwright smoke fails in GitHub Actions because the container runner installs `node_modules` on a tmpfs and then executes the Playwright shim through `npx`, which reports `playwright: Permission denied` under Docker in CI.

## Requirements

- Keep `make test-site` working locally through Podman.
- Keep CI and Pages using the same containerized Playwright smoke.
- Avoid host `node_modules` pollution.
- Do not require extra package installation on the GitHub runner beyond the existing container flow.

## Acceptance Criteria

- The Playwright container runner invokes Playwright in a way that does not depend on executable shims from the tmpfs-mounted `node_modules` tree.
- `make test-site SITE_IMAGE=` passes locally.
- Documentation or issue notes record the CI failure and fix.

## Notes

- Failed runs: CI `28328307297`, Pages `28328307318`.
- Both failed with `sh: 1: playwright: Permission denied` in `scripts/run_site_playwright_container.sh`.
- Fixed by invoking Playwright through `node node_modules/@playwright/test/cli.js test` instead of executing the package shim from `node_modules/.bin`.
- Verification passed: `make test-site SITE_IMAGE=`.
