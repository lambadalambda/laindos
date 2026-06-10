# Make game tests parallel-safe

## Summary

The game/CD tests use fixed global resources: `scripts/test_sammax_cd_start.py:81` and `scripts/test_sammax_cd_setmuse_save.py:97` both hardcode `-vnc 127.0.0.1:59` (concurrent runs fail to bind), and all game/CD tests use fixed `tempfile.gettempdir()` monitor-socket names (`laindos-wolf3d-smoke.sock`, `laindos-mi2-save.sock`, ...) and fixed VNC displays 29-64, so none can run twice concurrently on one host. (The default `run_tests.py -j4` suite is unaffected — those tests keep sockets in per-test build dirs.)

## Requirements

- Derive VNC display numbers and monitor socket paths from the PID or the per-test build dir, via a shared helper in testlib.

## Acceptance Criteria

- Two instances of the same game test run concurrently without resource collisions; all game Makefile targets still pass.

## Resolution

Resolved 2026-06-10. testlib gained unique_vnc_display/unique_vnc_arg (PID-derived display 100-899) and unique_monitor_socket (PID-suffixed temp path); all 18 game/CD tests use them instead of fixed VNC displays 29-64 and fixed socket names. build_wolf3d.py and test_wolf3d_smoke.py also honor LAINDOS_TEST_BUILD_DIR so the acceptance demo runs cleanly: two concurrent wolf3d smokes with separate build dirs both pass, as does the serial make target. Tests reading the shared heavyweight images (games_hd_all, monkey_full) still serialize on those image files; only the VNC/socket layer was in scope.
