# Add LOAD_SUBDIR_SECTOR helper

## Summary

Three sites in `src/kernel/path_dir.inc` (lines 1186, 1378, 1668) repeat the same 11-line "load LBA pair, call read_sector, set ES:DI to SEC_BUF" block, plus mirrored write-paths in `src/kernel/fs.inc:90-100` and `src/kernel/fat.inc:182-185` that share the same skeleton. The total duplication is roughly 33 lines.

## Requirements

- Introduce a `LOAD_SUBDIR_SECTOR <lba_var>, <err_label>` macro, or a real helper `read_subdir_sector` that takes the LBA pair and returns a pointer to the loaded sector in SEC_BUF.
- Migrate the three read sites to the new form.
- Optionally migrate the mirrored write sites in the same change.
- Verify no filesystem or FAT regression.

## Acceptance Criteria

- The refactor reduces each migrated read site from 11 lines to 1 macro call (or 1 helper call).
- Existing path-parsing, FAT, and directory tests still pass.
- `make test` passes.

## Notes

- Relevant sites: `src/kernel/path_dir.inc:1186-1199, 1378-1389, 1668-1679`, `src/kernel/fs.inc:90-100`, `src/kernel/fat.inc:182-185`.
- The LBA pair is stored in two kernel globals (`<x>_lba_hi` and `<x>_lba`); the macro/helper can take the prefix as an argument.
- Discovered during a whole-system review on 2026-06-06.
