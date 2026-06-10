# Make game tests parallel-safe

## Summary

The game/CD tests use fixed global resources: `scripts/test_sammax_cd_start.py:81` and `scripts/test_sammax_cd_setmuse_save.py:97` both hardcode `-vnc 127.0.0.1:59` (concurrent runs fail to bind), and all game/CD tests use fixed `tempfile.gettempdir()` monitor-socket names (`laindos-wolf3d-smoke.sock`, `laindos-mi2-save.sock`, ...) and fixed VNC displays 29-64, so none can run twice concurrently on one host. (The default `run_tests.py -j4` suite is unaffected — those tests keep sockets in per-test build dirs.)

## Requirements

- Derive VNC display numbers and monitor socket paths from the PID or the per-test build dir, via a shared helper in testlib.

## Acceptance Criteria

- Two instances of the same game test run concurrently without resource collisions; all game Makefile targets still pass.
