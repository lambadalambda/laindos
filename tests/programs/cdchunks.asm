[bits 16]
[org 0x0100]

; CD file reads across every chunk-size class: sub-sector, exact-sector,
; multi-sector, and tail reads must all return the right bytes. The
; pattern file holds byte[i] = (i ^ (i >> 8) ^ (i >> 16)) & 0xFF and is
; not a sector multiple, so the last read is a partial tail.

FILE_SIZE equ 200001
BUF_MAX   equ 0x7800

start:
    push cs
    pop ds
    cld

    ; the boot launcher loads this COM into a block barely larger than
    ; the file, with SP at the block top -- reading into an in-image
    ; buffer would overrun the block and the program's own stack, so
    ; the read buffer is a separately allocated 32 KiB block
    mov bx, 0x0800
    mov ah, 0x48
    int 0x21
    jc fail_alloc
    mov [bufseg], ax

    mov dx, fname
    mov ax, 0x3D00
    int 0x21
    jc fail_open
    mov [handle], ax

    ; chunk-size schedule exercises slow path, fast path, and the
    ; boundaries between them
    mov si, chunks
.next_chunk_size:
    mov cx, [si]
    test cx, cx
    jz .schedule_done
    call read_and_check
    jc fail_data
    add si, 2
    jmp .next_chunk_size
.schedule_done:
    ; everything after the schedule in one big-loop sweep
.sweep:
    mov cx, BUF_MAX
    call read_and_check
    jc fail_data
    cmp word [done_flag], 1
    jne .sweep

    ; total must equal the file size
    cmp word [total_lo], FILE_SIZE & 0xFFFF
    jne fail_total
    cmp word [total_hi], FILE_SIZE >> 16
    jne fail_total

    ; reads at EOF return zero bytes
    mov bx, [handle]
    mov cx, 16
    xor dx, dx
    push ds
    mov ds, [cs:bufseg]
    mov ah, 0x3F
    int 0x21
    pop ds
    jc fail_eof
    test ax, ax
    jnz fail_eof

    ; seek to an odd offset crossing a sector boundary and re-verify
    mov bx, [handle]
    mov cx, 0
    mov dx, 2047
    mov ax, 0x4200
    int 0x21
    jc fail_seek
    mov word [total_lo], 2047
    mov word [total_hi], 0
    mov word [done_flag], 0
    mov cx, 3
    call read_and_check
    jc fail_seek

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

; CX = chunk size. Reads into the allocated buffer block, verifies the
; pattern at offset [total], and advances [total]. Sets [done_flag] at
; EOF. CF on mismatch/error.
read_and_check:
    push si
    push ds
    mov bx, [handle]
    xor dx, dx
    mov ds, [cs:bufseg]
    mov ah, 0x3F
    int 0x21
    pop ds
    jc .bad
    test ax, ax
    jnz .have_data
    mov word [done_flag], 1
    jmp .ok
.have_data:
    mov cx, ax
    xor si, si
.verify:
    ; expected = (i ^ (i>>8) ^ (i>>16)) & 0xFF for i = [total]
    mov al, [total_lo]
    xor al, [total_lo+1]
    xor al, [total_hi]
    push ds
    mov ds, [cs:bufseg]
    cmp al, [si]
    pop ds
    jne .bad
    inc si
    add word [total_lo], 1
    adc word [total_hi], 0
    loop .verify
.ok:
    pop si
    clc
    ret
.bad:
    pop si
    stc
    ret

fail_alloc:
    mov dx, fail_alloc_msg
    jmp fail
fail_open:
    mov dx, fail_open_msg
    jmp fail
fail_data:
    mov dx, fail_data_msg
    jmp fail
fail_total:
    mov dx, fail_total_msg
    jmp fail
fail_eof:
    mov dx, fail_eof_msg
    jmp fail
fail_seek:
    mov dx, fail_seek_msg
fail:
    push cs
    pop ds
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

handle: dw 0
bufseg: dw 0
total_lo: dw 0
total_hi: dw 0
done_flag: dw 0
chunks: dw 1, 7, 512, 1527, 2047, 2048, 2049, 4096, 6144, 30720, 0
fname: db 'D:\PATTERN.BIN', 0
pass_msg: db 'PASS: CDCHUNKS', 13, 10, '$'
fail_alloc_msg: db 'FAIL: CDCHUNKS ALLOC', 13, 10, '$'
fail_open_msg: db 'FAIL: CDCHUNKS OPEN', 13, 10, '$'
fail_data_msg: db 'FAIL: CDCHUNKS DATA', 13, 10, '$'
fail_total_msg: db 'FAIL: CDCHUNKS TOTAL', 13, 10, '$'
fail_eof_msg: db 'FAIL: CDCHUNKS EOF', 13, 10, '$'
fail_seek_msg: db 'FAIL: CDCHUNKS SEEK', 13, 10, '$'
