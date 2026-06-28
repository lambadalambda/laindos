# Fix Docs Site Layout And Runtime Regressions

## Summary

User feedback identified several hosted docs-site regressions: blank content pages, right-column scrolling/layout problems, horizontal overflow, clipped emulator text, and no sound in the on-site emulator.

## Requirements

- Fix the blank `dosapi.html`, `memory.html`, and `programs.html` pages.
- Prevent unexpected horizontal page overflow on `run.html` and `tests.html` at a 1440px effective viewport width.
- Ensure the emulator text area is not clipped at the bottom.
- Restore or enable emulator audio when browser support allows it.
- Preserve the existing docs-site visual language and page structure.

## Acceptance Criteria

- The affected pages render nonblank locally.
- `run.html` and `tests.html` fit within a 1440px viewport without page-level horizontal scrolling.
- Emulator output text is fully visible vertically in the local page.
- The emulator requests/enables audio in the embedded v86 setup, subject to browser autoplay constraints.
- `make check-docs-sync` passes.

## Notes

- Hosted reports referenced `https://lambadalambda.github.io/laindos/run.html`, `dosapi.html`, `memory.html`, `programs.html`, and `tests.html`.
- Fixed with a shared `CodeBlock` anchor-label guard, constrained docs-site two-column/sidebar layout CSS, right-column internal scrolling, right-edge glossary popover positioning, safer v86 text line-height, and explicit `disable_speaker: false` in the embedded v86 options.
- Added `make test-site`, which runs `tests/site/docs_site.spec.js` inside `mcr.microsoft.com/playwright:v1.61.1-noble` through Podman locally and Docker in both CI and the Pages workflow.
- Verification passed: `make test-site`, `make test-site SITE_IMAGE=`, `make check-docs-sync`, `deno check docs/site/*.jsx scripts/build_site.jsx`, and `git diff --check`.
- This issue was opened in `meta/issues.md` at the start of the slice and archived after verification in the same working change.
