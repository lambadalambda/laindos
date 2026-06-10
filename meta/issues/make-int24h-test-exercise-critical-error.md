# Make the INT 24h test exercise the critical-error path

## Summary

`tests/programs/int24h.asm` asserts nothing: the whole program is set-DS, print `PASS: INT24H`, exit (int24h.asm:4-14). It never installs an INT 24h handler or triggers a disk error; `scripts/test_int24h.py` defines a `TESTFILE` it never uses, and its required markers can only fail if the kernel does not boot. The "INT 24h wiring" regression (archived issue wire-int24h-into-sector-io-loop) is effectively untested.

## Requirements

- Rework the test to install an INT 24h handler via AH=25h, force a disk error (e.g. read from an invalid sector via a crafted FAT, or use QEMU blkdebug fault injection), and assert the handler was invoked with the documented register contract and that fail/retry responses behave.

## Acceptance Criteria

- The test fails if the `int 0x24` invocation in `sector_io_loop` (src/kernel/disk.inc:58) is removed, and passes on current code; `PASS:` markers.

## Resolution

Resolved 2026-06-10. tests/programs/int24h.asm installs a handler via AX=2524h, then creates a file on a floppy QEMU exposes with readonly=on -- the INT 13h write fails, sector_io_loop retries, and INT 24h fires with the kernel's contract (AL=op 3 for write, AH=BIOS drive). The handler answers retry (AL=1) once, then fail (AL=3), and the program asserts the create errored, the handler ran at least twice, and the recorded op/drive match. Verified that stubbing out the `int 0x24` invocation in sector_io_loop makes the test fail. blkdebug fault injection remains unusable for this (see the earlier investigation note); the write-protected floppy supplies a genuine INT 13h error instead.
