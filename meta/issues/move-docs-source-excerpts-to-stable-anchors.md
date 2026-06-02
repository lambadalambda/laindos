# Move Docs Source Excerpts To Stable Anchors

## Summary

The docs sync checker catches stale source excerpts, but line-number-based excerpts create maintenance churn whenever nearby code shifts. Stable source anchors would keep docs accurate without making unrelated refactors update line numbers.

## Requirements

- Design a lightweight anchor format for source excerpts, such as named comments around excerpt regions.
- Update `scripts/check_docs_sync.py` and static site data to resolve excerpts by anchor where practical.
- Keep existing line-number checks working until anchored excerpts cover the important pages.
- Avoid adding browser-side runtime dependencies or weakening docs validation.

## Acceptance Criteria

- At least one interactive docs page uses stable source anchors instead of hardcoded line numbers.
- `python3 scripts/check_docs_sync.py` validates anchored excerpts.
- `deno check docs/site/*.jsx scripts/build_site.jsx` passes.
- `make site` passes.

## Notes

- Relevant checker: `scripts/check_docs_sync.py`.
- Relevant site source: `docs/site/page_*.jsx` and `docs/site/data.jsx`.
- This refines the archived `Add Documentation Source Sync Checks` work rather than replacing it.
