# Line-buffer CON device handle reads

## Summary

AH=3Fh on a CON device handle (`.rf_con`, `src/kernel/int21.inc:3138-3155`) blocks until exactly CX bytes are typed: no CR termination and no echo, so a program doing `read(con, buf, 128)` hangs until 128 keypresses. It also ignores the CF=1/AL=0 extended-key signal from `console_read_char` (`src/kernel/console.inc:73-83`) and `stosb`'s the 0 byte into the caller's buffer, injecting NULs on cursor/function keys. Real DOS CON reads are line-buffered and return at CR (returning CR/LF in the buffer).

## Requirements

- Implement line-buffered CON reads: echo input, handle backspace, return on CR with CR (and LF per DOS convention) in the buffer, and return the actual byte count.
- Skip or translate extended keys instead of storing NUL.

## Acceptance Criteria

- Test: AH=3Fh with CX=128 on handle 0 returns after a single line is typed, with correct count and trailing CR/LF; extended keys do not insert NULs; `PASS:` markers via QEMU sendkey scripting.
- Depends on / coordinates with [Support standard handles in read and seek](support-std-handle-read-and-seek.md).
