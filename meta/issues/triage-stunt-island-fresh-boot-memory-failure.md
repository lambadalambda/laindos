# Triage Stunt Island Fresh-Boot Memory Failure

## Summary

Stunt Island reportedly refuses to start because it complains about memory even on a fresh boot.

## Requirements

- Build or document a local Stunt Island repro image without committing proprietary game files.
- Capture the exact memory error text and launch path on a fresh boot.
- Compare LainDOS reported conventional memory, largest executable block, environment size, and MCB layout against a known-good DOS run where practical.
- Check whether the failure depends on XMS/EMS detection, EXE `MinAlloc`/`MaxAlloc`, PSP top-of-memory fields, or allocation strategy behavior.
- Add focused memory or loader regression coverage for any identified compatibility gap.

## Acceptance Criteria

- The fresh-boot memory complaint is reproduced and explained.
- Stunt Island starts, or the remaining memory requirement is documented with a concrete missing DOS behavior.
- `make test` passes after any implementation change.

## Notes

- Reported symptom: "complains about memory even on fresh boot".
- This may overlap with the process-memory-release issue only if repeated launches make the symptom worse; the initial report says fresh boot also fails.
