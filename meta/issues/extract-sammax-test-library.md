# Extract a Sam & Max test library

## Summary

All 8 Sam & Max scripts (1,284 lines: 7 `test_sammax_cd_*.py` + `run_sammax_cd.py`) carry identical copies of `extract_member()` and `prepare_cd_image()` plus the CUE/BIN/ISO path constants (e.g. test_sammax_cd_install_select.py:36-52 ≡ run_sammax_cd.py:30-46), and 4 duplicate the 27-line `text_screen_with_attrs()` B800 screen-scraper; `wait_for_upper_output`/`output_text` are duplicated in 2. Roughly 300-400 removable lines.

## Requirements

- Create `scripts/sammaxlib.py` (or extend testlib with the screen scraper, which the Norton Commander tests could also use) and migrate all 8 scripts.

## Acceptance Criteria

- All sammax Makefile targets pass; grep shows one definition each of `extract_member`/`prepare_cd_image`/`text_screen_with_attrs` under scripts/.
