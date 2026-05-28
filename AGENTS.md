# AGENTS.md

Rules and conventions for AI agents working on LainDOS.

## Project summary

LainDOS is a tiny single-tasking DOS implementation targeting x86 real mode. Its first goal is booting The Secret of Monkey Island. See `README.md` and `docs/gpt_handoff.md` for full details.

## Working conventions

### Test-Driven Development (TDD)

- Write tests first whenever possible. LainDOS targets x86 real mode and tests run under QEMU emulation; the code is written to be hardware-compatible. "Tests" means: small 16-bit DOS programs compiled with Open Watcom that exercise one DOS API surface at a time, plus automated QEMU launch-and-check scripts.
- Before implementing a new `INT 21h` function, write a tiny test program that calls it and asserts expected behavior.
- Run the test ladder (tiny programs → simple utilities → Monkey Island) after every change.

### Get reviews before committing

- Before committing any change, request a code review using the `code-reviewer-zai` agent.
- Do not commit until the review is incorporated or explicitly waived.
- After the review is incorporated or explicitly waived and the relevant checks pass, agents may commit without asking for additional approval.

### Ask advisors when you need help

- When you hit a complex problem, ambiguous design decision, or tricky real-mode issue, ask the `critical-advisor-zai` and `critical-advisor-deepseek` agents for a second opinion.
- Use their feedback to make better decisions; you don't have to follow every suggestion, but you must consider them.

### Commit topical, commit early, commit often

- Each commit should address one concern: one interrupt handler, one filesystem operation, one loader fix, etc.
- Do not bundle unrelated changes.
- Commit as soon as a coherent step compiles and passes its test — do not accumulate large diffs.

### Track progress with repo issues

- Use the repo-issues skill to manage milestones in `meta/issues/`.
- When a phase is complete and acceptance criteria are satisfied, move its entry from `meta/issues.md` to `meta/issues_archive.md`, changing `- [ ]` to `- [x]`.
- Do not delete issue detail files when archiving.

### Keep a debug log

- Maintain `docs/debug_log.md` while debugging non-trivial issues.
- Record current symptoms, confirmed facts, failed hypotheses, tests run, and next probes before switching approaches.
- Update the log whenever an investigation produces useful information, even if the result is negative.
- Prefer concise dated entries with commands and observed output markers so future agents do not repeat the same probes.

### Toolchain workflow

- Use the host tools that are already available in this workspace. NASM, Python, QEMU, and Bochs may be invoked directly.
- Do not install missing toolchains or package-manager dependencies yourself. If a required tool is missing, stop and ask the user for it.
- Prefer small NASM-built 16-bit test programs plus QEMU/Bochs runs for regression coverage.

### QEMU for running x86 code

- All LainDOS code runs as x86 real-mode software. Use **QEMU** (system emulator, i386 or x86_64 with appropriate `-cpu` flags) to boot disk images and run the kernel and test programs.
- Use **Bochs** when you need its debugger for tricky real-mode issues, but QEMU is the default run target.
- QEMU invocations should redirect serial output to a file or stdio so test scripts can inspect it.
- Test programs should output `PASS:` or `FAIL:` markers on serial for automated checking.
- Prefer `make run`, `make test`, or `$LAINDOS_QEMU` for local commands. The repo defaults to the sibling patched QEMU build when present because Ascendancy currently needs the local `SAHF` fix.
- Example baseline invocation:

  ```
  "${LAINDOS_QEMU:-qemu-system-i386}" -drive file=disk.img,format=raw -serial stdio -monitor none -nographic
  ```

### Build and run workflow

- If a Makefile or build script does not yet exist, create one before writing implementation code.
- Build: `make`
- Test: `make test`
- Run: `make run`

### License hygiene

- Do NOT copy code from FreeDOS kernel (GPL). It may be read for understanding only.
- MS-DOS 4.00 source (MIT) is acceptable as structural reference but do not copy verbatim.
- When in doubt about license compatibility, stop and ask the user.

### Sandbox constraints

- This agent runs in a sandboxed environment. If you need software that is not already available, **stop and ask the user for help** rather than failing silently or working around the constraint.
- Do not attempt `sudo`, `brew install`, `apt-get install`, or similar package-manager commands unless you have confirmed the environment permits it.
- If a required tool is missing and you cannot obtain it, report exactly what is needed and why.

## Code style

- C code targets Open Watcom's 16-bit DOS C compiler. Use its conventions and limits (near/far pointers, 16-bit `int`, etc.).
- Assembly is written in NASM syntax, real-mode focused.
- No comments unless explicitly requested.
- Case-insensitive 8.3 filenames for all DOS filesystem code.

## Key references

- `docs/gpt_handoff.md` — full architecture, phase plan, and API surface
- Ralf Brown's Interrupt List — exact register behavior for DOS/BIOS interrupts
- MS-DOS 4.00 source (MIT license) — structural reference only, do not copy verbatim
- FreeDOS kernel (GPL) — conceptual reference only, do not copy code
