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
| `AH=01h/02h/06h/07h/08h/09h/0Ah/0Bh` | implemented/partial | high | Existing shell and console tests cover core behavior; keep extended-key two-byte behavior protected. |
| `AH=03h/04h/05h` AUX/PRN I/O | missing/deferred | low | Depends on serial/printer device policy. |
| `AH=0Ch` flush and read | missing/partial candidate | medium | Common runtime call; flushes keyboard buffer then invokes AL subfunction `01h`/`06h`/`07h`/`08h`/`0Ah`. Should clear DOS pending extended-key state and BIOS buffer consistently before dispatch. |

### Process, PSP, Environment, and EXEC

| Area | Current Status | Priority | Notes |
| --- | --- | --- | --- |
| PSP creation and command tails | implemented/partial | high | Covered by `PSPTEST`, `ARGTEST`, `ARGEXE`, and game smokes. |
| `AH=4B00h` EXEC | implemented/partial | high | Supports COM/EXE, MZ relocation, command tails, MaxAlloc. Needs more parameter-block and environment edge tests. |
| `AH=4B03h` overlay load | implemented/partial | high | Covered by overlay regression; preserve for MI2-style overlays. |
| Environment block, `COMSPEC`, `PATH`, executable path tail | partial/missing | high | Tracked by Phase 15; needed for broader installer and shell compatibility. |
| `AH=4Dh` child return code | implemented/partial | medium | Needs tests around repeated reads and failed EXEC paths. |
| `AH=62h` get PSP | implemented | medium | Trivial but common runtime call; returns the current PSP segment. |
| `AH=31h` TSR/keep process | missing/deferred | low | Defer unless a target installer/runtime requires it. |

### Memory Management

| Area | Current Status | Priority | Notes |
| --- | --- | --- | --- |
| MCB arena and ownership | implemented/partial | high | Covered by memory, register-preservation, and game smokes. |
| `AH=48h/49h/4Ah` | implemented/partial | high | Preserve non-return registers, largest-block failure returns, PSP top updates. Add more failure-path tests. |
| `AH=58h` allocation strategy | implemented/partial | medium | Verify first/best/last behavior and unsupported subfunctions. |
| EXE `MinAlloc`/`MaxAlloc` loading | implemented | high | Covered by `EXEMAX`; protect packed-EXE load segment with `PACKSEG`. |

### File Handles and Filesystem

| Area | Current Status | Priority | Notes |
| --- | --- | --- | --- |
| `AH=3Ch/3Dh/3Eh/3Fh/40h/41h/42h` | implemented/partial | high | Existing write, readwrap, savewrite, dirmut, and game tests cover core paths. See Phase 9 and Phase 13 for related writable FAT work. |
| `AH=43h` attributes | implemented/partial | medium | Strengthen read-only/hidden/system/archive semantics. |
| `AH=45h/46h` duplicate/force duplicate handle | missing | medium | Common C runtime and redirection support. |
| `AH=57h` get/set file date/time | implemented/partial | medium | Preserve directory entry updates. |
| `AH=5Ah/5Bh` temp/create-new | missing | medium | Useful for installers and save systems. |
| `AH=67h` set handle count | missing/stub candidate | medium | Many runtimes call this defensively. |
| `AH=68h` commit file | missing/stub candidate | medium | Can initially flush/no-op successfully for local FAT images. |

### Directories and Paths

| Area | Current Status | Priority | Notes |
| --- | --- | --- | --- |
| `AH=39h/3Ah/3Bh/47h` | implemented/partial | high | Directory mutation tests cover core behavior. |
| `AH=4Eh/4Fh` find first/next | implemented/partial | high | Preserve DTA layout and wildcard behavior. |
| `AH=56h` rename | implemented/partial | medium | Strengthen cross-directory and overwrite failure behavior. |
| DOS device names `CON`, `NUL`, `AUX`, `PRN` | missing/partial | high | Tracked by Phase 17. |
| `AH=29h` parse filename | missing | low/medium | Useful for old FCB-era utilities and installers. |

### Disk, IOCTL, and Miscellaneous

| Area | Current Status | Priority | Notes |
| --- | --- | --- | --- |
| `AH=0Eh/19h` current drive | implemented/minimal | medium | Single-drive assumptions still visible. |
| `AH=1Ah/2Fh` DTA | implemented | high | Covered by find-first/find-next behavior. |
| `AH=25h/35h` vectors | implemented | high | Required by games. |
| `AH=2Ah/2Ch` date/time | implemented/partial | medium | Time advances from BIOS ticks; set-date/time missing. |
| `AH=30h` DOS version | implemented/minimal | medium | Keep target-version behavior explicit. |
| `AH=36h` disk free | minimal stub | medium | Replace total-as-free with real FAT free cluster count. |
| `AH=44h` IOCTL | minimal stub | high | Expand caller-driven subfunctions: get info, status, removable/local queries. |
| `AH=1Bh/1Ch` drive data | missing | low/medium | Some installers query media geometry. |
| `AH=33h/54h` Ctrl-C and verify state | missing/stub candidate | low/medium | Often queried defensively. |

### Deferred or Out of Scope Until Needed

| Area | Current Status | Priority | Notes |
| --- | --- | --- | --- |
| FCB calls | missing/deferred | low | Implement only if a target program uses them. |
| Sharing/locking `AH=5Ch` | missing/deferred | low | Single-tasking local DOS can return sensible unsupported/no-op behavior if needed. |
| Network calls `AH=5Eh/5Fh`, IOCTL remote queries | missing/deferred | low | Return local/not-remote semantics only if callers require it. |
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
