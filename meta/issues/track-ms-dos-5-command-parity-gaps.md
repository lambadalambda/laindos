# Track MS-DOS 5.0 Command Parity Gaps

## Summary

Record the current gap between LainDOS bundled commands/tools and the common MS-DOS 5.0 command set, without treating the list as implementation work.

LainDOS should not chase full `COMMAND.COM` or external utility parity by default. Most commands listed here are likely churn unless a real game, installer, setup program, utility, or focused regression demonstrates a concrete need. When a command becomes relevant, split it into a small issue with exact syntax, behavior, and tests rather than implementing broad MS-DOS command-suite coverage from this tracker.

## Requirements

- Keep this as a parked audit/backlog tracker, not a work-ready implementation issue.
- Do not implement commands only because they appear in this list.
- Split out a focused issue before implementing any command or option.
- Require a target trace, failing installer/game, or focused repro before moving a row out of parked status.
- Prefer narrow command behavior needed by observed callers over full MS-DOS clone behavior.
- Update this tracker when a listed command is split out, resolved, rejected, or reclassified.

## Current LainDOS Command Surface

| Command / Area | Current LainDOS Status | MS-DOS 5.0 Parity Notes | Evidence |
| --- | --- | --- | --- |
| `DIR` | Partial | Supports paths/patterns, raw byte counts plus human-readable summaries, `/P`, and `/W`; not full DOS option surface. | `docs/site/page_shell.jsx:14` |
| `CD` / `CHDIR` | Mostly supported | Includes `CD..`, `CD\`, and drive-qualified paths. | `docs/site/page_shell.jsx:15` |
| `MD` / `MKDIR` | Supported | Creates directories. | `docs/site/page_shell.jsx:16` |
| `RD` / `RMDIR` | Supported | Removes empty directories. | `docs/site/page_shell.jsx:17` |
| `COPY` | Partial | Supports file and wildcard copies plus `/Y` and `/-Y`; no full `COPY` syntax such as concatenation or `/A`/`/B`. | `docs/site/page_shell.jsx:19` |
| `DEL` / `ERASE` | Partial | Supports file and wildcard deletion plus optional `/P`. | `docs/site/page_shell.jsx:19` |
| `DELTREE` | Supported extension | DOS 6-style recursive delete with optional `/Y`; useful for current workflows but not an MS-DOS 5 command. | `docs/site/page_shell.jsx:18` |
| `REN` / `RENAME` | Partial | One file, same-directory rename; destination must be a filename. | `docs/site/page_shell.jsx:21` |
| `TYPE` | Supported | Streams one file to stdout. | `docs/site/page_shell.jsx:22` |
| `CLS` | Supported | Clears screen via form feed. | `docs/site/page_shell.jsx:22` |
| `ECHO` | Partial | Prints text; `ECHO ON/OFF` are accepted as quiet no-ops, not full echo-state behavior. | `docs/site/page_shell.jsx:23` |
| `REM` | Supported | Batch/comment no-op. | `docs/site/page_shell.jsx:24` |
| `PAUSE` | Mostly supported | Includes `> NUL` suppression. | `docs/site/page_shell.jsx:25` |
| `IF` | Partial | Supports `NOT`, `EXIST`, `ERRORLEVEL`, and equality forms for observed batch users. | `docs/site/page_shell.jsx:44`, `docs/site/page_shell.jsx:106` |
| `GOTO` | Partial | Labels are supported; missing label prints an error and ends the batch. | `docs/site/page_shell.jsx:44` |
| `BREAK` | Compat/no-op | Accepted but not full user-mode Ctrl-Break policy. | `docs/site/page_shell.jsx:26` |
| `MODE` | Very narrow | Only `MODE CO80` and `> NUL` suppression. | `docs/site/page_shell.jsx:27` |
| `MORE` | Narrow | Supports `MORE < file`, paging, and `> NUL`. | `docs/site/page_shell.jsx:28` |
| `EXIT` | Supported | Terminates the shell. | `docs/site/page_shell.jsx:12` |
| `VER` | Supported | Prints the LainDOS version/banner. | `docs/site/page_shell.jsx:13` |
| Drive switches | Supported | `A:`, `B:`, `C:`, etc. work when the drive is mounted. | `docs/site/page_shell.jsx:29` |
| Program launch | Partial | Runs `.COM`, `.EXE`, and `.BAT` from current directory or `PATH`; commands inherit partial stdout redirection with `>`/`>>`. | `docs/site/page_shell.jsx:30`, `docs/site/page_shell.jsx:69` |

## Bundled External/User Tools

| Tool | Current LainDOS Status | MS-DOS 5.0 Parity Notes | Evidence |
| --- | --- | --- | --- |
| `SHELL.COM` | Partial `COMMAND.COM` replacement | Enough for current game launchers and installers; not a full clone. | `docs/site/page_shell.jsx:42-47` |
| `FREE.COM` / `MEM.COM` | Partial | MS-DOS-style memory report, not full `MEM` option parity. | `programs/free.asm` |
| `TIME.COM` | Partial | Displays current time only; no interactive set flow. | `programs/time.asm` |
| `LOADFIX.COM` | Targeted subset | Implements the useful MS-DOS 5 low-load avoidance behavior for EXEPACK-style problems. | `programs/loadfix.asm` |
| `INSTALL.COM` | LainDOS-specific | Formats/updates LainDOS FAT16 hard disks; not an MS-DOS command. | `programs/install.asm` |

## Missing Shell and Batch Commands

| MS-DOS 5 Command | Current LainDOS Status | Default Disposition |
| --- | --- | --- |
| `CALL` | Missing | Split only for a real batch script that needs call/return semantics. |
| `FOR` | Missing | Defer; likely churn unless an installer needs loops. |
| `SET` | Missing | Plausibly useful if a game installer needs environment mutation. |
| `PATH` command | Missing | Plausibly useful if an installer or user workflow needs runtime PATH changes. |
| `PROMPT` | Missing | Defer unless user-facing shell parity becomes a goal. |
| `SHIFT` | Missing | Split only for batch scripts needing `%1`-`%9` shifting. |
| `DATE` | Missing | Kernel date API exists; add only if a caller or manual workflow needs it. |
| `VERIFY` | Missing | Kernel verify flag exists; command probably churn until needed. |
| `VOL` | Missing | Small and possibly useful if installers check volume labels; split only with a repro. |
| `CTTY` | Missing | Defer; no alternate console device support. |
| `CHCP` | Missing | Defer; code-page support is intentionally narrow. |

## Missing Common External Commands

| Category | Missing Commands | Default Disposition |
| --- | --- | --- |
| Disk/volume tools | `ATTRIB`, `CHKDSK`, `DISKCOMP`, `DISKCOPY`, `FDISK`, `FORMAT`, `LABEL`, `SYS`, `TREE` | `ATTRIB`, `LABEL`, or `SYS` may be useful with concrete callers; `VOL` is tracked in the shell-command table above; the rest are likely churn. |
| File/text tools | `COMP`, `FC`, `FIND`, `REPLACE`, `SORT`, `XCOPY` | Defer unless an installer batch uses one. |
| Editors/development tools | `DEBUG`, `EDIT`, `EDLIN`, `EXE2BIN`, `QBASIC` | Defer; not game-runtime compatibility work. |
| Recovery/backup tools | `BACKUP`, `RESTORE`, `RECOVER`, `UNDELETE`, `UNFORMAT`, `MIRROR` | Defer; high churn and low game value. |
| Environment/device helpers | `APPEND`, `ASSIGN`, `FASTOPEN`, `GRAPHICS`, `GRAFTABL`, `JOIN`, `KEYB`, `NLSFUNC`, `PRINT`, `SETVER`, `SHARE`, `SUBST` | Defer except `SETVER` or `SHARE` if a target explicitly probes them. |

## Acceptance Criteria

- This tracker remains open until the command backlog is intentionally re-triaged, split into smaller issues, or explicitly archived as obsolete.
- Any implementation spawned from this tracker has its own concrete issue, focused target/repro, tests where feasible, and exact acceptance criteria.
- Rows that are resolved, split out, or rejected are updated here so future agents do not rediscover the same audit.

## Notes

- The open command table in `programs/shell.asm` currently includes `EXIT`, `VER`, `DIR`, `CD`, `CD..`, `CHDIR`, `MD`, `MKDIR`, `RD`, `RMDIR`, `COPY`, `DEL`, `ERASE`, `DELTREE`, `REN`, `RENAME`, `TYPE`, `CLS`, `ECHO`, `REM`, `IF`, `GOTO`, `PAUSE`, `BREAK`, `MODE`, and `MORE`.
- See `track-ms-dos-5-compatibility-gaps.md` for the system-level shell compatibility view; this tracker keeps the per-command rows.
- The current shell behavior is intentionally scoped to games, installers, and regression tests rather than full `COMMAND.COM` compatibility.
- Treat this tracker as a warning against broad command-suite churn.
