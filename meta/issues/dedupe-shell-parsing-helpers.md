# Deduplicate shell parsing helpers

## Summary

`programs/shell.asm` repeats several near-identical routines: `copy_dir_operand` (174-207) vs `copy_path_token` (1000-1032); `confirm_copy_overwrite` (1118-1146) vs `confirm_del_prompt` (1299-1322) (identical Y/N prompt, different messages); `parse_pause_scan`/`parse_mode_scan`/`parse_more_scan` (1773-1891) are three near-identical `>NUL` scanners; `print_current_drive_letter` (818-829) duplicated inline in `print_drive_root` (2197-2207); the find-last-separator scan appears in `set_dir_header_from_pattern` (246-258) and `copy_src_basename_ptr` (1097-1111); `batch_label_match` (1686-1726) re-implements `cmd_match`'s case-folding compare. Dead state: `dir_dir_count` is incremented (438, 460) but never printed by `print_dir_summary` (593-612).

## Requirements

- Consolidate each duplicated pair/triple into one parameterized routine; either print `dir_dir_count` in the DIR summary (matching DOS "n dir(s)") or delete it.

## Acceptance Criteria

- Binary still assembles within size limits; all shell/batch tests pass unchanged (pure refactor except the DIR summary decision, which gets a test).

## Notes

- While here: `COPY A A` currently relies on the kernel's open-handle create guard for safety and prints a generic "File error"; printing "File cannot be copied onto itself" would match MS-DOS (shell.asm:870-918).
