# Tidy script utility rough edges

## Summary

Low-severity hygiene items from the 2026-06-10 review of scripts/: (a) `unlzexe.py` has no caller anywhere in scripts/Makefile/mise, and it never rebuilds the relocation table — it copies the compressed header's count (0) while discarding segment markers in the bitstream (unlzexe.py:92-94, 121), so any relocation-bearing LZEXE input decompresses to a broken EXE with no warning; document the limitation or remove the tool. (b) `testlib.kill_qemu_at_exit` atexit entries are never unregistered (harmless accumulation), and `wait_for_output`/`chunks_contain` re-join the whole chunk list every 20 ms — O(n^2) on chatty serial logs. (c) `run_tests.py:148-156` removes the build root only on full-suite success, so repeated failing runs accumulate `build/tests/run-<pid>` dirs unboundedly. (d) `scripts/test_cd_86box.py:22` hardcodes the macOS 86Box app path as the default (env-overridable, fails loudly — minor).

## Requirements

- Address each item or record an explicit won't-fix rationale in this file.

## Acceptance Criteria

- `make test` passes; failing-run build dirs are bounded (e.g. cleaned at start of the next run); unlzexe's status is decided and documented.
