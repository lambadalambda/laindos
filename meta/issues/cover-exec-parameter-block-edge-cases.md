# Cover EXEC Parameter Block Edge Cases

## Summary

Add focused coverage for `INT 21h AX=4B00h` EXEC parameter-block behavior, including error returns, null/default parameter blocks, command tails, default environments, and default FCB copying.

## Requirements

- Unsupported EXEC subfunctions fail with invalid-function errors.
- Missing EXEC paths fail with file-not-found errors.
- A null parameter block produces an empty child command tail and zero default FCBs.
- A populated parameter block copies the command tail and default FCBs into the child PSP.
- A zero environment segment allocates a default child environment.
- Update the Phase 19 compatibility matrix status for `AH=4B00h`.

## Acceptance Criteria

- A focused parent/child regression covers the parameter-block edges.
- Existing EXEC, return-code, environment, shell, and game smoke tests still pass.
- `make test` passes.
