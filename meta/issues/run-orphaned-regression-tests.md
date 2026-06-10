# Re-list orphaned regression tests and add suite discovery

## Summary

`scripts/run_tests.py` runs a hardcoded 97-entry list while 119 `test_*.py` files exist. 19 of the unlisted tests have dedicated Makefile targets (vendor-media games), but three are run by nothing: `scripts/test_badreloc.py`, `scripts/test_ctrunc.py`, and `scripts/test_mi2_save.py` appear in no Makefile target, no mise task, not in `DEFAULT_TESTS`, and not in CI — even though the Makefile still builds `badreloc.com`/`badreloc.exe`/`ctrunc.com` into `disk.img` (Makefile:46-49, 211-212). Nothing asserts that every test script is reachable, so the suite rots silently.

## Requirements

- Add the three orphans back to `DEFAULT_TESTS` (or their proper Makefile target for media-dependent ones like test_mi2_save).
- Add a discovery assertion in run_tests.py: every `scripts/test_*.py` must be in `DEFAULT_TESTS` or an explicit `EXTERNAL_TESTS` known-exclusion list, else the suite fails.

## Acceptance Criteria

- `make test` runs (or explicitly excludes with justification) every test_*.py; deleting a list entry without excluding it makes the suite fail; the three orphans pass.

## Notes

- `test_mi2_save.py` also has a hand-rolled QEMU pipe race (double-reading proc fds, scripts/test_mi2_save.py:155-237) — migrate it to testlib helpers when re-enabling.

## Resolution

Resolved 2026-06-10. test_badreloc.py and test_ctrunc.py are back in DEFAULT_TESTS (both pass). test_mi2_save.py got a vendor-gated `make test-mi2-save` target; running it surfaced a real EXC 06 crash in the MI2 save dialog, filed separately as fix-mi2-save-dialog-crash.md. run_tests.py now asserts at startup that every scripts/test_*.py is either in DEFAULT_TESTS or in the documented EXTERNAL_TESTS exclusion set (and that no listed script is missing); unknown or missing entries abort the suite with exit 2.
