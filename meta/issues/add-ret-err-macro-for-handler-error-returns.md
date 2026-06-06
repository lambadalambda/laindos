# Add RET_ERR macro for handler error returns

## Summary

53 direct adjacent pairs in `src/kernel/int21.inc` follow the pattern `mov ax, <err_code>` immediately followed by `jmp iret_cy`, plus another 16 sites that load `mov ax, [cs:<handler>_status]` before the same `jmp iret_cy`. Each pair is 2 lines, and the duplication totals roughly 106 lines.

## Requirements

- Introduce a `RET_ERR <code>` macro that emits `mov ax, <code>` and `jmp iret_cy`.
- Introduce a sibling `RET_ERR_STATUS` macro that emits `mov ax, [cs:<handler>_status]` and `jmp iret_cy` (or fold it into `RET_ERR` with a sentinel).
- Migrate at least the 53 literal-code sites; the 16 status-load sites can come in a follow-up.
- Place the macro definition next to `iret_nc`/`iret_cy` in `src/kernel.asm:383-412` or in a shared include.
- Verify no test regression.

## Acceptance Criteria

- The refactor reduces each migrated site from 2 lines to 1.
- Existing INT 21h tests still pass.
- A focused test (e.g. `python3 scripts/test_dup.py` or any test that hits an error path) verifies the AX and CF return values are unchanged.
- `make test` passes.

## Notes

- Relevant sites: `src/kernel/int21.inc:304-305, 307-308, 886-887, 915-916, 928-929, 953-954, 966-967, 977-978, 1255-1256, 1266-1267, 1937-1938, 2120-2121, 2124-2125, 2576-2577, 2666-2667, 2717-2718, 3037-3038, 3334-3335, 3477-3478, 3482-3483, 3692-3693, 3737-3738, 3790-3791, 3839-3840, 3979-3980, 4077-4078, 4084-4085, 4186-4187, 4220-4221, 4369-4370, 4373-4374, 4377-4378, 4413-4414, 4417-4418, 4540-4541, 4547-4548, 4598-4599, 4607-4608`.
- The 16 status-load sites are a follow-up; the issue scope is the 53 literal-code sites.
- Discovered during a whole-system review on 2026-06-06.
