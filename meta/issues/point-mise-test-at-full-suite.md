# Point mise test at the full suite and snapshot the boot test image

## Summary

`mise.toml`'s `[tasks.test]` ("Run automated QEMU boot tests") runs only `python3 scripts/test_boot.py`, while `make test` runs the 97-test suite plus docs sync — a contributor using `mise run test` gets a green light from a single boot smoke. Additionally, `test_boot.py` runs QEMU read-write against the shared prebuilt `build/disk.img` with no `-snapshot` (scripts/test_boot.py:26-33; run_tests.py:113 exempts it from per-test build dirs), so kernel writes dirty an artifact the Makefile will not rebuild — later runs test a stale, mutated image.

## Requirements

- Make `mise run test` invoke `make test` (or rename/redescribe the task honestly).
- Run `test_boot.py` with `-snapshot` or a per-run copy of the image.

## Acceptance Criteria

- `mise run test` exit status reflects the full suite; running the boot test twice produces a byte-identical `build/disk.img` (checksum before/after).
