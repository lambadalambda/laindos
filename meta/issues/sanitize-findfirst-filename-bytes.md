# Sanitize FindFirst filename bytes

## Summary

`store_find_dta` in `src/kernel/path_dir.inc` copies the on-disk 8.3 name bytes into the DTA at `[es:di+30]` via `stosb` without sanitizing the bytes. The size math (8+1+3+1 = 13 bytes, well within the 43-byte DTA find-first block) is fine, but a crafted or corrupt directory entry containing `0x00`, `0xE5`, or control characters in the 8.3 region is propagated unfiltered into every `FindFirst`/`FindNext` consumer. The shell at `programs/shell.asm:192` then prints those bytes straight to the console, allowing a malicious disk image to inject embedded NULs that truncate displayed filenames or control chars that reprogram the terminal.

## Requirements

- Convert on-disk `0xE5` (the deleted-entry marker) to `0x05` or another safe glyph before storing, since the 8.3 region uses raw bytes and the on-disk `0xE5` is the marker for a deleted entry but the on-disk value for `0xE5` itself.
- Replace embedded NULs and control characters in the 8.3 region with a substitute glyph (e.g. `?`).
- Preserve the `0x20` (space) padding that DOS expects in the 8.3 region.
- Add focused regression coverage that builds a directory with a `0xE5` byte in the name and verifies the consumer sees a safe glyph, not the deleted-entry marker.

## Acceptance Criteria

- A regression creates a directory entry whose first name byte is `0xE5` and verifies the DTA filename returned by FindFirst is not the deleted-entry marker.
- A regression creates a directory entry with an embedded NUL in the name and verifies the DTA filename does not contain a literal NUL.
- The same regression verifies the shell display path does not truncate the filename at the NUL.
- Existing FindFirst/FindNext and shell tests still pass.
- `make test` passes.

## Notes

- Relevant code: `src/kernel/path_dir.inc:2025-2059` (`store_find_dta`), consumer at `programs/shell.asm:192`.
- The deleted-entry marker `0xE5` is a documented DOS quirk: the on-disk marker is `0xE5` and the on-disk value for the character `0xE5` in a filename is `0x05`. Most DOS clones follow this convention.
- Discovered during a whole-system review on 2026-06-06.
