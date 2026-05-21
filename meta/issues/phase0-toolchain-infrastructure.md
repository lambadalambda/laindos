# Phase 0: Toolchain & Infrastructure

## Summary

Set up the build container, Makefile, and QEMU test runner so that the project can actually be built and tested before any DOS code is written.

## Requirements

- Podman Containerfile with NASM and Open Watcom 16-bit toolchain
- Makefile with `build`, `test`, and `clean` targets
- Script or Make target to create a bootable FAT12 disk image
- QEMU invocation helper or Make target for running disk images
- Serial output redirected to stdio for test inspection

## Acceptance Criteria

- `podman build` produces a working build container
- `podman run --rm -v $(pwd):/src <container> make` compiles a stub kernel without errors
- `make test` launches QEMU, boots the image, and captures serial output
- `PASS:` / `FAIL:` markers in serial output can be grepped by the test runner
