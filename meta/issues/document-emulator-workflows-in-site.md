# Document Emulator Workflows In The Site

## Summary

Bring the emulator workflow knowledge into the interactive documentation so users can reproduce QEMU, 86Box, Bochs, v86, and real-DOS comparison runs without reading scattered notes.

## Requirements

- Add an emulator workflow page or track to `docs/site/`.
- Cover default QEMU usage, patched QEMU selection, precise VGA retrace, serial logging, VNC, monitor sockets, screenshots, and smoke tests.
- Cover when to use Bochs, 86Box, v86, or real DOS in QEMU.
- Document known emulator-specific hazards, including Ascendancy's `SAHF` issue and v86 VGA BIOS selection.

## Acceptance Criteria

- The site has a discoverable emulator workflow page.
- The page links to `docs/emulator_workflows.md`, `docs/debug_log.md`, and relevant Makefile targets.
- Users can identify the right emulator and command for boot tests, shell demo tests, Monkey Island, Wolfenstein 3D, and Ascendancy.
- Local site smoke confirms the page renders without console errors.

## Notes

- Keep the source-of-truth docs synchronized rather than duplicating stale command blocks.
