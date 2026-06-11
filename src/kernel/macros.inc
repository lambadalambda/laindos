; Shared small macros usable from any kernel include.

; Skip a leading "X:" drive prefix on a DS-relative path register.
%macro STRIP_DRIVE_PREFIX 1
    mov al, [ds:%1]
    call ascii_upper
    cmp al, 'A'
    jb %%skip
    cmp al, 'Z'
    ja %%skip
    cmp byte [ds:%1+1], ':'
    jne %%skip
    add %1, 2
%%skip:
%endmacro

; Increment a 32-bit value stored as two cs-relative words.
%macro INC_DWORD_CS 2
    inc word [cs:%1]
    jnz %%done
    inc word [cs:%2]
%%done:
%endmacro
