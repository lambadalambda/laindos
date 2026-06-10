# Make the INT 24h test exercise the critical-error path

## Summary

`tests/programs/int24h.asm` asserts nothing: the whole program is set-DS, print `PASS: INT24H`, exit (int24h.asm:4-14). It never installs an INT 24h handler or triggers a disk error; `scripts/test_int24h.py` defines a `TESTFILE` it never uses, and its required markers can only fail if the kernel does not boot. The "INT 24h wiring" regression (archived issue wire-int24h-into-sector-io-loop) is effectively untested.

## Requirements

- Rework the test to install an INT 24h handler via AH=25h, force a disk error (e.g. read from an invalid sector via a crafted FAT, or use QEMU blkdebug fault injection), and assert the handler was invoked with the documented register contract and that fail/retry responses behave.

## Acceptance Criteria

- The test fails if the `int 0x24` invocation in `sector_io_loop` (src/kernel/disk.inc:58) is removed, and passes on current code; `PASS:` markers.
