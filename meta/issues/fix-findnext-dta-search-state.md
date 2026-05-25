# Fix FindNext DTA Search State

## Summary

`INT 21h AH=4Fh` currently continues directory searches from kernel globals instead of the search state stored in the active DTA. Interleaved file operations, another `FindFirst`, or DTA switching can corrupt `FindNext` results.

## Requirements

- Restore the search template, attribute mask, entry index, and directory cluster from the current DTA before `FindNext` searches.
- Preserve DOS-visible register and carry-flag behavior for `AH=4Eh` and `AH=4Fh`.
- Avoid relying on mutable globals such as `name_buf`, `ff_attr_mask`, `ff_entry_idx`, and `ff_dir_cluster` as the only continuation state.

## Acceptance Criteria

- A regression proves `FindFirst`, an interleaved file operation or second search, DTA restoration, and `FindNext` continue the original search.
- Existing shell and directory tests still pass.
- `FindNext` returns no duplicate or skipped entries in the covered interleaving case.

## Notes

- Reviewers flagged `src/kernel.asm` around `.find_next` as the highest-risk latent bug.
- `store_find_dta` already stores entry index and directory cluster into DTA offsets `+13` and `+15`.
- The wildcard template at DTA `+1..+11` and attribute mask at DTA `+12` also need to be restored.
- Root-directory index overflow should be considered while fixing this; bad `fid_idx` should not wrap into a plausible root entry.
