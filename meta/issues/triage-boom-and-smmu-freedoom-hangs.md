# Triage Boom And SMMU FreeDoom Hangs

## Summary

FreeDoom with Boom and SMMU reportedly hangs under LainDOS.

## Requirements

- Build or document local Boom and SMMU FreeDoom repro images without committing external game data.
- Capture serial output, framebuffer state, and the last known progress point for each executable.
- Determine whether the hangs are DOS API, file I/O, memory/XMS, DPMI/protected-mode, timer, keyboard, or emulator-behavior related.
- Compare with real DOS under the same QEMU/86Box setup when the failure looks emulator-specific.
- Add focused regression coverage for any DOS behavior that explains either hang.

## Acceptance Criteria

- Boom and SMMU each have a recorded reproducible failure signature.
- Both launch far enough to run FreeDoom content, or each remaining blocker is isolated into a documented follow-up.
- `make test` passes after any implementation change.

## Notes

- Reported symptom: "FreeDoom (Boom and SMMU, hangs)".
- Local repro image: `vendor/FreeDOS.VHD` attached as `C:` while booting `build/shell_monkey.img` from `A:` with QEMU `-snapshot` and `-device sb16`.
- Initial SMMU Phase 1 runs repeatedly hit Windows LFN probes and reported `IWAD not found`; returning the DOS 7 unsupported-LFN signal `AX=7100h` lets SMMU fall back to 8.3 APIs and find `doom.wad`/`smmu.wad`.
- Added focused `COMPATAPI` coverage for `AH=50h/51h`, `AH=60h`, `AX=5D06h`, and unsupported `AH=71h` behavior.
- Current SMMU Phase 1 and Phase 2 smokes find their IWADs, add the IWAD/SMMU WAD, enter protected-mode graphics initialization, and show active framebuffers with no `EXC ` and no unhandled `INT 21h AH=` trace.
- Current Boom smoke finds `./doom.wad`, reaches `I_InitSound`, `S_Init`, `HU_Init`, and `ST_Init`, and shows an active framebuffer with no `EXC ` and no unhandled `INT 21h AH=` trace.
- Remaining blocker: Boom still appears to stall after `ST_Init`, and SMMU still appears to sit in protected-mode graphics startup. The next probe should compare the same Boom/SMMU binaries under real DOS in QEMU and/or 86Box before treating the remaining behavior as another LainDOS DOS API issue.
