# Document The Test Ladder And Regression Workflow

## Summary

Add documentation that teaches contributors how to add and run LainDOS regression tests, from tiny DOS programs through game smoke tests.

## Requirements

- Document the expected test ladder: tiny DOS programs, shell/utilities, filesystem image tests, game smoke tests.
- Explain how NASM test programs are built, how images are assembled, how QEMU serial output is checked, and how screenshots/framebuffer checks work.
- Include a template or checklist for adding a new `INT 21h` test.
- Explain when to run `make test`, `make test-monkey-demo`, game smokes, and local Playwright checks for the site.

## Acceptance Criteria

- A contributor can add a new API regression test by following the docs.
- The docs link to representative test scripts and programs.
- `README.md` or the interactive site points to the test-writing guide.
- Existing test commands in the guide match current Makefile targets.

## Notes

- This issue is about making the process teachable, not changing the test harness itself unless docs expose a small missing helper.
- Resolved with `docs/test_ladder.md` and the interactive `Tests · Regression Ladder` site track.
