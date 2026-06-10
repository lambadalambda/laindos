# Apply shared helpers across INT 21h and path code

## Summary

Several existing or obvious helpers are open-coded repeatedly: (a) the `STRIP_DRIVE_PREFIX` macro (`src/kernel/path_dir.inc:28-39`) is hand-expanded at least 6 times in int21.inc (2125-2133, 3613-3624, 4374-4382, 4455-4463, 4499-4507, 4518-4526); (b) the 12-instruction file-position-to-(cluster index, sector-in-cluster) computation is triplicated in the read/write paths (int21.inc:2946-2957, 3240-3251, 3318-3329) — a `pos_to_cluster_sector` helper keeps read/write from drifting; (c) `.rm_done`/`.rm_err` carry a byte-for-byte duplicated 32-line manual trace block (1711-1787) and `.alloc_mem` hand-rolls two trace prologues (1392-1419, 1537-1554) instead of the existing TRACE macros; (d) the handle-slot release sequence is duplicated 4 times with drifting field lists (path_dir.inc:267-270, 333-337, 386-389, 462-466); (e) the `inc lo / jnz / inc hi` 32-bit LBA bump appears 7 times (path_dir.inc:1229, 1391, 1449, 1579, 1674, 2132; disk.inc:133); (f) `find_in_dir`'s root branch re-derives what `root_entry_loc_from_cx` computes (path_dir.inc:1147-1161 vs 1331-1352); (g) `serial_print_hex_word` duplicates the nibble loop of `serial_print_hex` (`src/kernel/console.inc:271-313`).

## Requirements

- Adopt the existing macros/helpers at the open-coded sites and extract the missing ones (`pos_to_cluster_sector`, handle-release helper, LBA-increment macro).

## Acceptance Criteria

- Pure refactor: full ladder passes; grep confirms single definitions and macro use at the listed sites.

## Notes

- Latent register-contract hazard in the same area: `find_in_dir`'s root branch clobbers DX while the subdir branch preserves it (path_dir.inc:1148 vs 1184-1185) — make the contract symmetric while refactoring.
