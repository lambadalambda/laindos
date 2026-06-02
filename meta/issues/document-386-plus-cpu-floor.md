# Document 386+ CPU Floor

## Summary

The boot sectors use 386+ instructions such as `movzx`. The project does not need pre-386 compatibility, but the minimum CPU expectation should be explicit so future reviewers do not treat those instructions as bugs.

## Requirements

- Document that LainDOS currently targets 386-compatible real-mode execution, not 8086/286 compatibility.
- Note that DOS-extender-era game work and QEMU i386/86Box validation make 386+ an acceptable CPU floor.
- Keep the boot-sector `movzx` usage unless there is a separate reason to change it.

## Acceptance Criteria

- `README.md` or architecture documentation states the minimum CPU expectation clearly.
- The note explains that pre-386 support is out of scope unless a future target requires it.
- No code churn is introduced solely to replace 386+ instructions with 8086-safe sequences.

## Notes

- Relevant instructions are in `src/boot.asm:44`, `src/boot.asm:57`, `src/boot.asm:112`, `src/boot.asm:115`, `src/boot16.asm:44`, `src/boot16.asm:61`, `src/boot16.asm:109`, and `src/boot16.asm:112`.
- This is intentionally a documentation issue, not a boot-code compatibility fix.
