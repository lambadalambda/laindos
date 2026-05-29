# Add Documentation Source Sync Checks

## Summary

Add lightweight checks that catch stale documentation when source excerpts, line numbers, test counts, or command references drift.

## Requirements

- Identify which documentation data is most likely to drift, especially `docs/site/data.jsx` source excerpts and hardcoded status text.
- Add a small script or CI check that validates source excerpt line numbers and referenced files where practical.
- Check that documented Makefile targets and linked files exist.
- Keep the check fast enough to run in CI and locally.

## Acceptance Criteria

- `make test` or a new documented command runs the docs sync check.
- The check fails if a site source excerpt points at the wrong current line or a missing file.
- The check is documented in `README.md`, `AGENTS.md`, or the test workflow docs.
- CI runs the check on pushes.

## Notes

- Start small. A partial checker for source excerpts is better than no drift detection.
