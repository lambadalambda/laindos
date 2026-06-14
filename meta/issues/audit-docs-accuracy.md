# Audit documentation accuracy against current kernel state

## Summary

A semantic audit of README.md and docs/site/ (2026-06-11) against the
current sources, prompted by the question whether the docs still
reflect the system after the recent fidelity and refactor work. The
mechanical sync gate (scripts/check_docs_sync.py) only verified excerpt
text, make targets, file references, and test counts, so prose claims
and excerpt-adjacent metadata could drift silently.

## Findings

- docs/site/page_dosapi.jsx and page_programs.jsx claimed EXEC
  load-only (`AH=4Bh AL=01h`) was "not implemented yet"; it is fully
  implemented (int21.inc `.exec_load`) and returns entry SS:SP/CS:IP
  through the parameter block. `AH=34h` (InDOS pointer) was handled
  but missing from the dosapi tables.
- docs/site/page_filesystem.jsx listed buffer segments from a pre-CD
  layout (`SEC_BUF 0B00`, `READ_CACHE_BUF 0B20`, `ROOT_SEG 0B40`);
  the then-current values were 0200/0220/0240.
- docs/site/data.jsx boot walkthrough carried pre-HMA, pre-0x0B00
  values: arena prose said 0x1000, the s4 register table showed the
  kernel CS as 0340, and the free-paragraph figures were 99BFh/614K
  (now 94FFh/~595K). Two excerpt entries were also pointed at the
  wrong occurrence of their line (`mov es, ax`, `mov ax,
  [cs:prog_seg]`).
- Site-wide: every page's `hi:` highlight arrays and data.jsx
  annotation keys had drifted out of their code blocks' line numbers —
  the doc-line auto-fixer re-points `code:` entries but never touched
  `hi:`/annotation keys, so excerpt highlighting silently stopped
  rendering and annotation chips showed wrong line numbers. 233 keys
  were recovered mechanically by walking each file's git history to
  the newest revision where the keys matched, mapping each key to its
  excerpt text, and re-keying it to that text's current line; the
  remaining ~25 (text rewritten or multiple drift generations) were
  re-keyed by hand, three of them onto existing `@anchor` entries.
- README.md "Current Status" omitted the Monkey Island 2 save/load
  milestone, Stunt Island install-to-gameplay, and the Norton
  Commander/Shortline smokes, and its site-page list omitted the
  emulators and glossary pages.
- False positive worth recording: the FAT12/FAT16 doc threshold
  ("fewer than 4085 clusters") is correct even though the kernel
  compares `kmax_cluster` against 4087 — `kmax_cluster` is the cluster
  count plus 2, so the comparison is the spec boundary in disguise.

## Resolution (2026-06-11)

- All content findings above fixed in README.md, page_dosapi.jsx,
  page_programs.jsx, page_filesystem.jsx, and data.jsx.
- All hi/annotation keys re-keyed to current excerpt lines across
  data.jsx, page_filesystem.jsx, page_memory.jsx, page_mouse.jsx,
  page_programs.jsx, and page_shell.jsx.
- scripts/check_docs_sync.py now validates that every numeric `hi:`
  value and numeric annotation key matches an excerpt line of its own
  code block, and that `{a: "..."}` hi anchors are excerpt entries of
  that block, so this class of drift fails `make test` instead of
  rotting silently.
