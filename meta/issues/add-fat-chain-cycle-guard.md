# Add cycle guard and shared FAT chain walker

## Summary

No FAT chain walker has a cycle guard, so a looped chain hangs the kernel. The walk idiom (`fat_next` + EOC/reserved/minimum checks) is duplicated at least six times with diverging guard sets: `src/kernel/path_dir.inc:1238-1245` (`find_in_dir`), 1400-1407 (`find_dir_free`), 1683-1690 (`dir_is_empty`), `src/kernel/fs.inc:220-228` (`wf_get_cluster`), `src/kernel/int21.inc:2969-2990` (read path — omits the reserved check), path_dir.inc:2140-2142 (`load_file_direct` — omits both upper guards).

## Requirements

- Introduce a `fat_next_checked` helper with a step bound (e.g. `kmax_cluster` iterations) returning CF on EOC/invalid/cycle, and convert all walkers to it.
- Guard sets must be identical across call sites.

## Acceptance Criteria

- Test image with a deliberately looped FAT chain: reading the file returns an error instead of hanging; `PASS:` markers.
- Existing FAT/read/write/dir tests pass.

## Notes

- Also fixes the inconsistency where the read path accepts reserved cluster values the other walkers reject.
