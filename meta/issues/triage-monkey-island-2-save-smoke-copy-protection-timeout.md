# Triage Monkey Island 2 Save Smoke Copy-Protection Timeout

## Summary

`make test-mi2-save` currently boots the all-games image but times out before the Monkey Island 2 copy-protection prompt appears.

## Requirements

- Determine whether the timeout is caused by test input timing, a stale generated image, QEMU monitor interaction, or a real Monkey Island 2 launch regression.
- Preserve the existing save-file validation once the smoke reaches the save dialog again.
- Keep the vendor archive and generated game images untracked.

## Acceptance Criteria

- `make test-mi2-save` reliably reaches the copy-protection prompt and completes its save validation, or the failure is narrowed to a specific product bug with a focused repro.
- If the issue is harness timing, the harness waits for a more stable signal than a fixed delay or fragile screen heuristic.
- The smoke continues to reject `FAIL:`, `EXC `, and unhandled `INT 21h AH=` markers.

## Notes

- Observed 2026-06-14 at `866b448` with `make -k test-game-smokes`.
- Failure: `RuntimeError: timed out waiting for copy-protection prompt` from `scripts/test_mi2_save.py`.
- The failure happens before the save dialog flow, so it is distinct from save-file validation itself.
- Triage found the same `2a484f8 perf: batch FAT handle reads` regression as full Monkey Island. The unaligned-buffer direct-read guard restores launch through the copy-protection flow and save validation.
- Resolved 2026-06-14. `make test-mi2-save` passes and creates `SAVEGAME.002` after requiring sector-aligned caller buffers for direct FAT multi-sector reads.
