# Add user-space handle count query and post-alloc_handle failure hook

## Summary

Issue #free-create-file-handle-on-directory-failure was closed as no-fix-needed on 2026-06-06, but the review surfaced a real test infrastructure gap: the existing tests can't reliably trigger or verify a handle leak because (a) `TEST_DIR_EXT_ZERO_FAIL` fires BEFORE `alloc_handle` runs, and (b) user space has no way to read the kernel's handle count. Closing the original issue was the right call, but the missing infrastructure should be tracked so it doesn't get lost.

## Requirements

- Add a kernel test hook that forces a failure AFTER `alloc_handle` succeeds (e.g., a new `TEST_FLUSH_DIR_SLOT_FAIL` flag in `flush_dir_slot`, analogous to `TEST_DIR_EXT_ZERO_FAIL`).
- Add a user-space API to query the kernel's current handle count. The natural fit is a new `AH=...` INT 21h subfunction, or a side channel via the existing `AH=4B` EXEC return. The cleanest approach is probably a small new `INT 21h` function or an extension of an existing one.
- Add a focused regression test that:
  1. Sets a low handle count via `AH=67h`.
  2. Triggers a forced post-`alloc_handle` failure (via the new test hook).
  3. Verifies the handle count is unchanged.
  4. Creates a real file and verifies the next open succeeds.
- Update `tests/programs/createapi.asm` or write a new test program to exercise the new path.

## Acceptance Criteria

- The kernel has a user-visible way to query the current handle count.
- A new test hook reliably forces a `flush_dir_slot` (or `flush_fat`) failure post-`alloc_handle`.
- A regression test verifies that the handle count is preserved across a failed create.
- Existing create/rename/durability tests still pass.
- `make test` passes.

## Notes

- Relevant code: `src/kernel/int21.inc:2295-2439` (`.create_file`), `src/kernel/path_dir.inc:1455-1462` (`TEST_DIR_EXT_ZERO_FAIL` template).
- This is a follow-up to the closed #free-create-file-handle-on-directory-failure. The original issue was closed because the fix was a no-op (the handle slot's `H_USED` is still 0 at the failure point, so there's nothing to free), but the underlying testability problem is real and worth tracking.
- The handle-count query could be implemented as a new `INT 21h` subfunction, e.g., `AH=...` returning the current user-handle count in `AX`. This is a small kernel addition and would also help future test scenarios.
- A non-test hook (e.g., a debug printout of handle state on failure) would also be useful for ad-hoc diagnosis but doesn't substitute for a queryable API.
