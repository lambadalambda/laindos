# Harden Interactive Documentation Delivery

## Summary

Improve the production-readiness of the GitHub Pages site by reducing runtime dependencies, strengthening CDN integrity, and making deployment failures easier to catch.

## Requirements

- Replace runtime Babel transformation with a precompiled site build or another lightweight production build path.
- Add subresource integrity or vendored pinned assets for external scripts where practical.
- Add cache-busting for `shell_monkey.img` when the image changes.
- Add a deployment or post-build smoke check that verifies the site files and image are present.
- Preserve the simple local authoring workflow or document the new build workflow clearly.

## Acceptance Criteria

- GitHub Pages no longer relies on browser-side Babel for normal production loads.
- External script integrity or vendoring decisions are documented.
- The deployed image URL changes or is cache-busted when the underlying image changes.
- CI catches missing site files or missing `shell_monkey.img` before deploy.

## Notes

- This is not required for the initial site to function, but it reduces long-term maintenance and supply-chain risk.
