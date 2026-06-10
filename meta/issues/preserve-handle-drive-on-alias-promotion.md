# Preserve handle drive on alias promotion

## Summary

When `close_handle_for_replace` promotes a dup alias to master (`src/kernel/path_dir.inc:411-440`), the copy block transfers MODE/CLUSTER/POS/SIZE/DIR_LBA/DIR_OFF/TIME/DATE/REFCOUNT but not `H_DRIVE`. The alias's `H_DRIVE` was stamped from `active_drive_num` at dup time (path_dir.inc:113-114), which may differ from the master's drive after any intervening path operation on another drive. After promotion, `activate_drive_for_handle` selects the wrong volume and reads/writes plus the close-time `flush_handle_dir_entry` apply the file's `H_DIR_LBA`/cluster chain to the wrong drive — cross-volume corruption.

## Requirements

- Copy `H_DRIVE` (and any other per-handle field not currently transferred) during alias promotion; prefer a single "copy handle body" helper so the field list cannot drift.

## Acceptance Criteria

- Multi-drive test: open file on B:, dup it, touch a path on A:, close the master, then read/write/close via the promoted alias and verify B:'s data and directory entry are correct while A: is untouched; `PASS:` markers.
- Existing dup/JFT tests pass.
