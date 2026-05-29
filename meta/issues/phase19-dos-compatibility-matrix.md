# Phase 19: DOS Compatibility Matrix

## Summary

Use the MS-DOS 4.0 Programmer's Reference as a structured compatibility checklist for LainDOS, while continuing to prioritize real game and installer behavior over implementing the entire DOS 4 surface area.

## Requirements

- Build and maintain a status matrix for DOS APIs and structures that LainDOS already touches or is likely to need for late-1980s and early-1990s games.
- Classify each item as implemented, partial/stubbed, missing, or intentionally deferred.
- Prefer test-first implementation using tiny 16-bit regression programs plus QEMU automation.
- Prioritize features observed in game traces, installers, setup programs, common DOS runtimes, and shell usage.
- Use the MS-DOS 4.0 Programmer's Reference, RBIL, DOSBox-X traces, and targeted emulator probes as behavior references.
- Do not copy manual prose or source code into the project; record behavior in our own words and tests.

Status key: `implemented` means tested core behavior exists; `partial` means subfunctions or edge cases are still missing; `stub` means the call returns a compatibility result without full semantics; `deferred` means intentionally out of scope until a caller requires it.

## Compatibility Matrix Seed

### Character and Console I/O

| Area | Current Status | Priority | Notes |
| --- | --- | --- | --- |
| `AH=01h/02h/06h/07h/08h/09h/0Ah/0Bh` | implemented/partial | high | Shell, `CONSOLE`, `KEY`, and `EXTKEY` cover core behavior, direct-console empty/data status, output return values, zero-length buffered input, line editing, stdin status, and extended-key two-byte behavior. |
| `AH=03h/04h/05h` AUX/PRN I/O | missing/deferred | low | Depends on serial/printer device policy. |
| `AH=0Ch` flush and read | implemented | medium | Covered by `FLUSHREAD`; clears the DOS pending extended-key state and BIOS keyboard buffer before dispatching AL subfunction `01h`/`06h`/`07h`/`08h`/`0Ah`. |

### Process, PSP, Environment, and EXEC

| Area | Current Status | Priority | Notes |
| --- | --- | --- | --- |
| PSP creation and command tails | implemented/partial | high | Covered by `PSPTEST`, `ARGTEST`, `ARGEXE`, and game smokes. |
| `AH=4B00h` EXEC | implemented/partial | high | Supports COM/EXE, MZ relocation, command tails, MaxAlloc, caller-provided environment segments, default/null parameter blocks, and default FCB copying. Covered by `EXECPARAM`, `EXECENV`, `RETCODE`, shell, and game smokes. |
| `AH=4B03h` overlay load | implemented/partial | high | Covered by overlay regression; preserve for MI2-style overlays. |
| Environment block, `COMSPEC`, `PATH`, executable path tail | implemented/partial | high | Default child environments are MCB-allocated per process; `EXECENV` covers caller-provided environment segment inheritance and ownership preservation. |
| `AH=4Dh` child return code | implemented/partial | medium | `RETCODE` covers initial zero state, destructive reads, nonzero child codes, and failed-`EXEC` preservation; non-normal termination types remain minimal. |
| `AH=62h` get PSP | implemented | medium | Trivial but common runtime call; returns the current PSP segment. |
| `AH=31h` TSR/keep process | missing/deferred | low | Defer unless a target installer/runtime requires it. |

### Memory Management

| Area | Current Status | Priority | Notes |
| --- | --- | --- | --- |
| MCB arena and ownership | implemented/partial | high | Covered by memory, register-preservation, and game smokes. |
| `AH=48h/49h/4Ah` | implemented/partial | high | `MEMFAIL`, `MEMREG`, and `REGPRES` cover failure returns, largest-block sizes, PSP top updates, and register preservation. |
| `AH=58h` allocation strategy | implemented/partial | medium | `STRATAPI` covers get/set, first/best/last allocation choices, and unsupported strategy/subfunction failures; UMB strategies remain unsupported. |
| EXE `MinAlloc`/`MaxAlloc` loading | implemented | high | Covered by `EXEMAX`; protect packed-EXE load segment with `PACKSEG`. |

### File Handles and Filesystem

| Area | Current Status | Priority | Notes |
| --- | --- | --- | --- |
| `AH=3Ch/3Dh/3Eh/3Fh/40h/41h/42h` | implemented/partial | high | Existing write, readwrap, savewrite, dirmut, and game tests cover core paths. See Phase 9 and Phase 13 for related writable FAT work. |
| `AH=43h` attributes | implemented/partial | medium | `ATTRAPI` covers mutable read-only/hidden/system/archive changes, protected directory/volume bit rejection, and directory-bit preservation. |
| `AH=45h/46h` duplicate/force duplicate handle | implemented/partial | medium | Covered by `DUPTEST`; duplicated file handles share position and close lifetime. Standard-handle redirection remains minimal. |
| `AH=57h` get/set file date/time | implemented/partial | medium | `FINDTIME`, `SAVEWRITE`, and `REGPRES` cover default timestamps, set/get, unsupported subfunction failure, close/reopen persistence, FindFirst visibility, on-disk directory entry updates, and register preservation. |
| `AH=5Ah/5Bh` temp/create-new | implemented/partial | medium | Covered by `CREATEAPI`; temp names use generated 8.3 `LDxxxx.TMP` names and skip existing collisions. |
| `AH=67h` set handle count | implemented/partial | medium | `HANDLECNT` and `CREATEAPI` cover low-count minimum behavior and larger defensive requests; LainDOS still caps effective handles at the fixed 20-entry table. |
| `AH=68h` commit file | implemented/partial | medium | Covered by `COMMITTEST`; flushes directory metadata/FAT for real files and succeeds for implicit standard handles. |

### Directories and Paths

| Area | Current Status | Priority | Notes |
| --- | --- | --- | --- |
| `AH=39h/3Ah/3Bh/47h` | implemented/partial | high | Directory mutation tests cover core behavior; `AH=47h` validates requested drives against the supported logical drive count. |
| `AH=4Eh/4Fh` find first/next | implemented/partial | high | `FINDNEXT`, `FINDATTR`, `FINDTIME`, and `PATHCANON` cover DTA layout/state, wildcard matching, attribute filters, timestamps, and multi-component paths. |
| `AH=56h` rename | implemented/partial | medium | `RNGUARD`, `SAVEWRITE`, and `HIGHDIR` cover normal, open-handle, read-only, same-directory overwrite, cross-directory failure, multi-component, and high-directory rename behavior. |
| DOS device names `CON`, `NUL`, `AUX`, `PRN` | implemented/partial | high | Phase 17 is archived; `DEVNAMES` covers case-insensitive and extension-insensitive `CON`/`NUL`, keeps prefix lookalikes as files, and verifies unsupported `AUX`/`PRN` return access denied. |
| `AH=29h` parse filename | implemented/partial | low/medium | `PARSEFCB` covers drive parsing, option-bit preservation, leading separator handling, wildcard return/asterisk expansion, invalid drive reporting, and separator termination. |

### Disk, IOCTL, and Miscellaneous

| Area | Current Status | Priority | Notes |
| --- | --- | --- | --- |
| `AH=0Eh/19h` current drive | implemented/partial | medium | `DRIVE` covers get/set current drive, stable logical drive counts, and boundary/high invalid-drive requests preserving the previous drive; still maps all supported drive letters to the boot image. |
| `AH=1Ah/2Fh` DTA | implemented | high | Covered by find-first/find-next behavior. |
| `AH=25h/35h` vectors | implemented | high | Required by games. |
| `AH=2Ah/2Bh/2Ch/2Dh` date/time | implemented/partial | medium | Date is state-backed with weekday calculation; time advances from BIOS ticks until `AH=2Dh` sets explicit state. `DATETIME`, `STATEAPI`, and shell `TIME` cover boundary validation, invalid-call preservation, and tick-derived time. |
| `AH=30h` DOS version | implemented/partial | medium | `VERSIONAPI` locks the compatibility identity to DOS 3.30 for `AH=30h` and `AX=3306h` true-version byte ordering. |
| `AH=36h` disk free | implemented/partial | medium | Counts free clusters from the active FAT and returns `AX=FFFFh` for invalid drives; covered by `DISKFREE` on FAT12 and FAT16. |
| `AH=44h` IOCTL | implemented/partial | high | `IOCTLEXT` and `IOCTLST` cover get/set info, input/output status, removable drive query, local drive/handle queries, unsupported subfunctions, and bad handle/drive errors for local files/devices. |
| `AH=1Bh/1Ch` drive data | implemented/partial | low/medium | `DRIVEDATA` covers default and explicit supported drives, FAT12/FAT16 BPB allocation values, media ID pointers, and boundary/high invalid-drive `AL=FFh` returns. |
| `AH=33h/54h/2Eh` Ctrl-C and verify state | implemented/partial | low/medium | Break get/set, boot-drive, true-version, and verify get/set are covered by `STATEAPI`. |

### Deferred or Out of Scope Until Needed

| Area | Current Status | Priority | Notes |
| --- | --- | --- | --- |
| FCB calls | missing/deferred | low | Implement only if a target program uses them. |
| Sharing/locking `AH=5Ch` | missing/deferred | low | Single-tasking local DOS can return sensible unsupported/no-op behavior if needed. |
| Network calls `AH=5Eh/5Fh` | missing/deferred | low | Return local/not-remote semantics only if callers require it. |
| NLS/code pages `AH=38h/65h/66h` | missing/deferred | low | Defer unless installer/runtime requires country/code-page data. |
| Installable DOS device drivers | missing/deferred | low | Prefer built-in device-name compatibility before CONFIG.SYS/device-driver work. |

## Acceptance Criteria

- A maintained compatibility matrix exists in this issue or a follow-up documentation file.
- Each newly implemented DOS function or semantic edge case gets a focused regression where feasible.
- Matrix status is updated when compatibility behavior changes.
- Broad compatibility work does not regress the existing `make test`, Monkey, MI2, Simon, QEMU, Bochs, and 86Box baselines relevant to the changed area.

## Notes

- Reference: https://www.pcjs.org/documents/books/mspl13/msdos/dosref40/
- Phase 18 is archived as complete; this phase tracks broader compatibility gaps exposed by the game bring-up work.
- Treat the manual as a behavioral guide, not as an implementation script.
- RBIL remains the best source for exact flags, register preservation, version differences, and undocumented quirks.
- Game traces and small repro programs should decide implementation order.
- Avoid adding broad compatibility stubs that hide real missing behavior unless a caller clearly treats success as acceptable.
