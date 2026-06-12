[bits 16]
[org 0x0100]

; MSCDEX answers an exclusive volume-label FindFirst (attribute 0x08)
; from the ISO9660 volume identifier, ignoring the search pattern --
; programs pass a bare "D:\" path. Red Alert identifies its discs this
; way ("CD1"/"CD2") and shows the insert-CD dialog if the query fails.

start:
    push cs
    pop ds
    cld
    ; DOS-style prologue: move the stack inside the kept region, then
    ; shrink the block so later allocations/execs have memory to use
    mov sp, 0x1FFE
    mov bx, 0x0200
    mov ah, 0x4A
    int 0x21

    ; 1. bare-root label query returns the volume id with attr 0x08
    mov dx, cd_root
    mov cx, 0x0008
    mov ah, 0x4E
    int 0x21
    jc fail_first
    cmp byte [0x80+21], 0x08
    jne fail_attr
    mov si, 0x80+30
    mov di, label_name
    call str_equal
    jc fail_name

    ; 2. FindNext after the label has nothing more to report
    mov ah, 0x4F
    int 0x21
    jnc fail_next

    ; 3. the pattern is ignored: a wildcard query gets the same label
    mov dx, cd_wild
    mov cx, 0x0008
    mov ah, 0x4E
    int 0x21
    jc fail_wild
    mov si, 0x80+30
    mov di, label_name
    call str_equal
    jc fail_wild

    ; 4. a normal search is not polluted by the synthetic label
    mov dx, cd_wild
    mov cx, 0x0010
    mov ah, 0x4E
    int 0x21
    jc fail_norm
    cmp byte [0x80+21], 0x08
    je fail_norm

    ; 5. FAT volumes without a label entry report no match
    mov dx, fat_wild
    mov cx, 0x0008
    mov ah, 0x4E
    int 0x21
    jnc fail_fat

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

; CF set if ASCIZ strings at DS:SI / DS:DI differ
str_equal:
    mov al, [si]
    cmp al, [di]
    jne .diff
    test al, al
    jz .same
    inc si
    inc di
    jmp str_equal
.same:
    clc
    ret
.diff:
    stc
    ret

fail_first:
    mov dx, fail_first_msg
    jmp fail
fail_attr:
    mov dx, fail_attr_msg
    jmp fail
fail_name:
    mov dx, fail_name_msg
    jmp fail
fail_next:
    mov dx, fail_next_msg
    jmp fail
fail_wild:
    mov dx, fail_wild_msg
    jmp fail
fail_norm:
    mov dx, fail_norm_msg
    jmp fail
fail_fat:
    mov dx, fail_fat_msg
fail:
    push cs
    pop ds
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

cd_root: db 'D:\', 0
cd_wild: db 'D:\*.*', 0
fat_wild: db 'C:\*.*', 0
label_name: db 'LAINCD', 0
pass_msg: db 'PASS: CDVOLID', 13, 10, '$'
fail_first_msg: db 'FAIL: CDVOLID FIRST', 13, 10, '$'
fail_attr_msg: db 'FAIL: CDVOLID ATTR', 13, 10, '$'
fail_name_msg: db 'FAIL: CDVOLID NAME', 13, 10, '$'
fail_next_msg: db 'FAIL: CDVOLID NEXT', 13, 10, '$'
fail_wild_msg: db 'FAIL: CDVOLID WILD', 13, 10, '$'
fail_norm_msg: db 'FAIL: CDVOLID NORM', 13, 10, '$'
fail_fat_msg: db 'FAIL: CDVOLID FAT', 13, 10, '$'
