; Shared small macros usable from any kernel include.

%ifndef PERF_IO_COUNTS
%define PERF_IO_COUNTS 0
%endif

%if PERF_IO_COUNTS
%ifndef TEST_HANDLE_COUNT_QUERY
%define TEST_HANDLE_COUNT_QUERY
%endif
%endif

%macro PERF_INC 1
%if PERF_IO_COUNTS
    inc word [cs:%1]
%endif
%endmacro

%macro PERF_INC_THEN_PUSH_AX 1
%if PERF_IO_COUNTS
    inc word [cs:%1]
%endif
    push ax
%endmacro

%macro INT21_STI 0
    sti
    cmp ah, 0x40
    je %%done
    cmp byte [cs:wf_sec_cache_dirty], 1
    je %%done
    mov byte [cs:wf_sec_cache_valid], 0
%%done:
%endmacro

%macro WF_PREREAD_CACHE_CHECK 0
    cmp byte [cs:wf_sec_cache_valid], 1
    jne %%miss
    mov ax, [cs:wf_sector_lba]
    cmp ax, [cs:wf_sec_cache_lba]
    jne %%miss
    mov ax, [cs:wf_sector_lba_hi]
    cmp ax, [cs:wf_sec_cache_lba_hi]
    jne %%miss
    mov al, [cs:active_drive_num]
    cmp al, [cs:wf_sec_cache_drive]
    jne %%miss
    clc
    jmp .wf_skip_preread
%%miss:
    PERF_INC perf_write_prereads
%endmacro

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
