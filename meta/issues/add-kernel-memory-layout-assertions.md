# Add Kernel Memory Layout Assertions

## Summary

Phase 17 exposed a boot relocation overlap after the kernel grew. The kernel now also has limited space before fixed buffers such as `SEC_BUF` and `ENV_SEG`.

## Requirements

- Add assembly-time checks that fail the build if the relocated kernel overlaps fixed buffers.
- Add assembly-time checks that fail the build if boot relocation source/destination ranges can overlap unsafely for the configured load segment.
- Keep the assertions tied to named memory-map constants rather than duplicated magic values.

## Acceptance Criteria

- `make` fails with a clear `%error` if the kernel grows into `SEC_BUF` or if relocation gap assumptions are violated.
- Current `make` and `make test` pass.

## Notes

- The current boot load segment was moved to `0x1000`, but future growth needs a hard guard instead of another latent boot corruption.
