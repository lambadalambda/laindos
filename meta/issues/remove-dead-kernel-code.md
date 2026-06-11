# Remove dead kernel code

## Summary

Dead or broken-if-used code found in the 2026-06-10 whole-repo review: (a) `exec_com` (`src/kernel/exec.inc:1265-1284`) is never called — only its trailing `.back: ret` is used as the terminate trampoline (`src/kernel.asm:2274`, 2343); the dead body still far-jumps to a hardcoded `PSP_SEG` and its 8-instruction prologue is repeated verbatim in `exec_exe_dyn`/`exec_com_dyn`. (b) `load_file` (`src/kernel/path_dir.inc:2160-2209`) has no callers and is wrong for `kspc > 1` volumes (reads only the first sector of each cluster). (c) `fname_hello` (kernel.asm:2921) and `find_di` (kernel.asm:3276) are unreferenced. (d) `.rp_empty`'s root comparison (`path_dir.inc:989-997`) branches to two byte-identical paths, leaving trailing-separator paths (`CD FOO\`) unresolvable — either implement the root case or delete the vacuous branch.

## Requirements

- Delete the dead code, move the `.back` trampoline label somewhere honest, deduplicate the launch prologue, and decide the `.rp_empty` trailing-separator semantics (MS-DOS accepts `CD FOO\`).

## Acceptance Criteria

- Full test ladder passes; a new shell/test case covers `CD FOO\` per the chosen semantics; grep shows no references to the removed symbols.

## Resolution (2026-06-11)

- (a) Deleted the dead `exec_com` body (and the now-unreferenced
  `PSP_SEG` constant). The terminate trampoline is now an honest
  standalone `exec_resume_parent: ret`, and the duplicated launch
  prologue lives in one `exec_begin_child` helper (saved_sp records the
  caller-frame SP, +2 over the helper's own frame).
- (b) Deleted `load_file` and its private `load_name`/`load_seg`/
  `load_off` variables (no callers; broken for kspc > 1).
- (c) Deleted `fname_hello` and `find_di`.
- (d) Implemented MS-DOS trailing-separator semantics in
  `resolve_path`: a component followed only by separators is treated as
  the final component and must be a directory, so `CD FOO\` works and
  `CD FILE.EXT\` fails; the vacuous `.rp_empty_root` branch is gone.
  TDD: `tests/programs/diredge.asm` gained CD-trailing cases that fail
  on the old kernel.
- Two pre-existing stale excerpts in page_filesystem.jsx (pointing into
  the deleted `load_file` while narrating `find_in_dir`/`find_dir_free`)
  were re-pointed to the real `fat_next_checked` call sites.
- Suite passes 139/139; kernel shrank 39085 -> 38926 bytes.
