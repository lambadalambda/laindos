# Remove dead kernel code

## Summary

Dead or broken-if-used code found in the 2026-06-10 whole-repo review: (a) `exec_com` (`src/kernel/exec.inc:1265-1284`) is never called — only its trailing `.back: ret` is used as the terminate trampoline (`src/kernel.asm:2274`, 2343); the dead body still far-jumps to a hardcoded `PSP_SEG` and its 8-instruction prologue is repeated verbatim in `exec_exe_dyn`/`exec_com_dyn`. (b) `load_file` (`src/kernel/path_dir.inc:2160-2209`) has no callers and is wrong for `kspc > 1` volumes (reads only the first sector of each cluster). (c) `fname_hello` (kernel.asm:2921) and `find_di` (kernel.asm:3276) are unreferenced. (d) `.rp_empty`'s root comparison (`path_dir.inc:989-997`) branches to two byte-identical paths, leaving trailing-separator paths (`CD FOO\`) unresolvable — either implement the root case or delete the vacuous branch.

## Requirements

- Delete the dead code, move the `.back` trampoline label somewhere honest, deduplicate the launch prologue, and decide the `.rp_empty` trailing-separator semantics (MS-DOS accepts `CD FOO\`).

## Acceptance Criteria

- Full test ladder passes; a new shell/test case covers `CD FOO\` per the chosen semantics; grep shows no references to the removed symbols.
