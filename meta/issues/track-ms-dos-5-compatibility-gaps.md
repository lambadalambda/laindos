# Track MS-DOS 5.0 Compatibility Gaps

## Summary

Record the current MS-DOS 5.0 compatibility and feature-parity gaps so they are not lost, without treating the full list as immediate implementation work.

LainDOS remains target-driven. Most of these gaps should stay parked until a game, installer, utility, or focused repro demonstrates a concrete need. When a gap becomes relevant, split it into a smaller issue with exact acceptance criteria and tests instead of implementing broad DOS surface area from this tracker directly.

## Requirements

- Keep this as an audit/backlog tracker, not an implementation issue.
- Do not implement broad compatibility surfaces only because they are listed here.
- Before working on any row, create or identify a target program, trace, or focused 16-bit regression that proves the behavior matters.
- Prefer small, caller-driven compatibility fixes over generic stubs that hide missing behavior.
- Update this tracker when a listed gap is split out, resolved, deemed obsolete, or reclassified.

## Compatibility Gap Snapshot

| Area | Current LainDOS State | MS-DOS 5.0 Parity Gap | Default Disposition | Evidence |
| --- | --- | --- | --- | --- |
| Full `COMMAND.COM` behavior | Small target-driven shell with partial output redirection. | Missing `SET`, prompt expansion, aliases, pipes, `CALL`, `FOR`, environment-variable expansion, and full input/error redirection. | Split only for a failing installer or real batch script; otherwise churn. | `docs/site/page_shell.jsx:42-47`, `docs/site/page_shell.jsx:69` |
| `CONFIG.SYS` and device drivers | Only `AUTOEXEC.BAT`; no config processing. | Missing `DEVICE=`, `FILES=`, `BUFFERS=`, `LASTDRIVE=`, `DOS=HIGH`, etc. | Worth considering only when a target install disk requires it. | `docs/status.md:43-49` |
| AUX/PRN/serial/printer | `AUX`/`PRN` names are detected but denied; `AH=03h/04h/05h` are absent. | DOS supports stdaux/stdprn device I/O and printer output. | Low priority; likely churn unless a setup utility probes it. | `src/kernel/path_dir.inc:225-236`, `src/kernel/path_dir.inc:625-695` |
| FCB file APIs | Only `AH=29h` parse and narrow `AH=11h/12h` current-directory search. | Missing broader FCB open/read/write/delete/rename/random-record APIs. | Target-driven; useful only for older software that actually uses FCB I/O. | `docs/site/page_dosapi.jsx:311-312` |
| Sharing and locking | No `AH=5Ch`; basic open/read-only guards only. | Missing byte-range locks and `SHARE` semantics. | Low priority for single-tasking DOS; split only for a concrete caller. | `AH=5Ch` entry in `meta/issues/track-deferred-dos-compatibility-apis.md` |
| Network and redirectors | No `AH=5Eh/5Fh`; local-only IOCTL answers. | Missing redirector, remote printer/drive, and session APIs. | Defer; likely churn for current game goals. | `docs/site/page_dosapi.jsx:212-215` |
| NLS/code pages/country | Minimal country table; code page 437 only; empty DBCS table; no `AH=65h`. | Missing full `COUNTRY.SYS`, NLS, code-page, and DBCS behavior. | Defer unless localized software needs it. | `docs/site/page_dosapi.jsx:323-327` |
| DOS internals | Minimal `AH=52h`; `AH=5Dh` only supports `AX=5D06h`. | Missing full list-of-lists, SDA, and internal DOS layout. | Target-driven; high risk of broad brittle compatibility churn. | `docs/site/page_dosapi.jsx:261-264` |
| Extended error and low-level disk structs | Unknown calls return function error; `AH=32h` returns a kernel-owned DOS 4-style DPB for mounted FAT drives. | Missing `AH=59h`, media-ID, and richer drive-internal query behavior beyond the current DPB. | Possible targeted utility/runtime fix if observed. | `docs/site/page_dosapi.jsx:257`, `docs/debug_log.md:84-110` |
| IOCTL | Partial selected local/device status subfunctions. | Missing many DOS IOCTL control and parameter operations. | Target-driven; expand only for a caller. | `src/kernel/int21.inc:4278-4312` |
| EXEC variants | `AL=00h`, `AL=01h`, and `AL=03h` only. | Other EXEC variants and edge semantics are absent. | Split only for a runtime/launcher that needs a missing variant. | `src/kernel/int21.inc:1951-1958` |
| Handle table size | `MAX_HANDLES=20`; `AH=67h` refreshes PSP metadata but does not expand the real table. | No real handle-table expansion like DOS `FILES=`-style behavior. | Potentially useful if a file-heavy app hits exhaustion; otherwise defer. | `src/kernel.asm:38`, `src/kernel/int21.inc:5264-5277` |
| Extended open/create | `AX=6C00h` supports the observed DOS 4+/5 open/create action cases needed by Biing. | Broader share/inheritance/mode edge semantics are not fully audited. | Resolved for the observed Biing installer path; expand only for a new caller. | `docs/site/page_dosapi.jsx:330`, `docs/debug_log.md:84-110` |
| Rename/move edge cases | Rename is same-directory only. | Broader DOS rename/move semantics are missing. | Split only if a file manager or installer needs move-like rename. | `docs/site/page_filesystem.jsx:288-289` |
| XMS | Single allocated handle, capped backing, no HMA allocation. | Missing multi-handle, realloc, fuller HMA/A20 semantics. | Target-driven; likely important only for specific extenders/games. | `src/kernel.asm:2108-2334`, `docs/status.md:47` |
| EMS | Disabled by default; opt-in implementation is narrow. | Missing normal EMM386-style multi-handle EMS. | Defer unless an EMS-required title becomes a target. | `docs/site/page_memory.jsx:346-351` |
| UMB/load-high | Conventional MCB arena only. | Missing UMBs, `LOADHIGH`, and high allocation strategies. | Defer; broad memory-manager work unless a target needs it. | `docs/status.md:47` |
| Drives/volumes | Practical A/B/C/D model; `MAX_DRIVES=4`. | No `LASTDRIVE`-style broad drive namespace. | Defer unless a target expects more drives. | `src/kernel.asm:65`, `docs/status.md:7` |
| Large disk/boot geometry | Simple partitioned FAT supported, but boot path is CHS-limited; docs warn about older 16-bit sector paths. | Less robust than a mature DOS 5 disk stack for large or unusual disks. | Worth revisiting if real DOS-compatible large images matter. | `docs/emulator_workflows.md:156-159` |
| Critical error handling | Default `INT 24h` returns Fail; disk retry path only honors Retry. | Missing full Abort/Retry/Ignore/Fail interaction and context. | Target-driven; useful for disk utilities or installer recovery paths. | `src/kernel/disk.inc:80-99`, `src/kernel.asm:2032-2034` |

## Not MS-DOS 5.0 Gaps

| Item | Note |
| --- | --- |
| Long filenames / `AH=71h` | MS-DOS 5.0 has no LFN API. LainDOS returning the unsupported fallback signal is a later Windows/DOS 7 compatibility courtesy, not a DOS 5 gap. |
| Full MSCDEX parity | Base MS-DOS 5.0 did not include MSCDEX as the kernel. LainDOS has a useful CD-ROM/MSCDEX subset, but full MSCDEX parity should be tracked separately only if a CD target requires it. |
| Full DPMI | Not a base MS-DOS 5 kernel feature. Self-managing DOS extenders can work when their real-mode DOS calls and CPU assumptions are satisfied. |

## Stale Audit Notes

- Archived compatibility notes in `cover-dos-version-identity-semantics.md`, `phase6-boot-monkey-island.md`, and `phase19-dos-compatibility-matrix.md` that say `AH=30h` reports DOS 3.30 are stale. Current source returns DOS 5.00 through `src/kernel/int21.inc:1063-1067`, and current status documents that at `docs/status.md:53`.
- The mouse documentation may understate current `INT 33h` support: source now includes state size/save/restore and driver info at `src/kernel/mouse.inc:47-67` and `src/kernel/mouse.inc:53-61`. This is a documentation cleanup candidate, not a DOS 5.0 kernel parity issue.

## Acceptance Criteria

- This tracker remains open until the compatibility backlog is intentionally re-triaged, split into smaller issues, or explicitly archived as obsolete.
- Any implementation work spawned from this tracker has its own concrete issue, focused repro or target trace, tests where feasible, and acceptance criteria.
- Rows that are resolved, split out, or intentionally rejected are updated here so future agents do not rediscover the same audit.

## Notes

- Current open issue index was empty when this tracker was created.
- The audit is based on current source and docs, not stale archived phase text.
- This tracker expands and supersedes the archived `track-deferred-dos-compatibility-apis.md` audit for current DOS 5 compatibility triage.
- Command-specific shell and utility parity is tracked separately in `track-ms-dos-5-command-parity-gaps.md`; the `COMMAND.COM` row here is the system-level pointer.
- Treat the rows marked low priority or deferred as warnings against churn, not as a mandate to chase full DOS completeness.
