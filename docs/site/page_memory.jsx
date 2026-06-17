const MEM_FLOW = [
  ["Layout", "The kernel relocates to the HMA at FFFF:0010, keeps scratch buffers below 0B00h, and reserves A000h for VGA."],
  ["Arena", "One free MCB starts at 0B00h and grows upward until MEM_TOP, with owner 0 meaning free."],
  ["Allocate", "INT 21h AH=48h supports first, best, and last-fit strategy, plus a high-biased small allocation path."],
  ["Own", "Program and environment blocks are stamped with the current PSP so exit cleanup can reclaim them."],
  ["Extend", "XMS is a single-handle BIOS-move shim; default EMS uses a validated upper-memory frame."]];

const MEM_REGIONS = [
  ["0000:0000", "IVT and BIOS data remain in low memory because hardware and BIOS calls still own them."],
  ["0060:0000", "FAT_SEG scratch space holds the resident FAT image and is reused by FAT12/FAT16 logic."],
  ["0180:0000", "CD_BUF is the 2 KiB ISO9660 sector buffer for the CD-ROM driver."],
  ["0200:0000", "SEC_BUF is the one-sector scratch buffer used by loader and filesystem paths."],
  ["0220:0000", "READ_CACHE_BUF is a four-sector FAT handle read-ahead cache."],
  ["02A0:0000", "ROOT_SEG holds the resident root directory image."],
  ["06A0:0000", "WRITE_CACHE_BUF is the one-sector hard-disk write-back buffer."],
  ["06C0:0000", "CD_CACHE_BUF holds the four 2 KiB CD file-read cache slots."],
  ["08C0:0000", "SUBDIR_CACHE_BUF holds sixteen FAT subdirectory sector cache slots."],
  ["0B00:0000", "MCB_START begins the DOS arena for programs, PSPs, environments, and normal allocations."],
  ["A000:0000", "MEM_TOP and VGA graphics memory; conventional allocations must stop before this segment."],
  ["D000:0000", "Default EMS page frame when PCI shadow RAM makes this upper-memory window writable."],
  ["FFFF:0010", "The High Memory Area holds the kernel image and stack; the A20 line is enabled at boot and kept on."]];

const MEM_SECTIONS = [
  {
    id: "constants",
    title: "Fixed segments define the machine",
    summary: "The low-memory layout is a contract, not a suggestion.",
    body: [
      "`src/memory.inc` is the first file to read before moving buffers. These equates decide where the boot sector loads the kernel, where the kernel relocates (the High Memory Area at FFFF:0010), where CD/FAT/read/write/subdirectory-cache scratch sectors live, where the DOS arena begins, and where conventional memory ends.",
      "With the kernel image and stack resident in the HMA, low memory holds only the filesystem scratch buffers: the DOS arena starts at 0B00h — kept at the lowest placement real MS-DOS could produce, because era programs (MONKEY2.EXE among them) corrupt themselves when loaded below that — and VGA graphics memory begins at A000h. `MEM_TOP` must stay 256-byte aligned because several bounds checks compare segment values directly."],
    file: "src/memory.inc",
    code: [
      [3, "LOAD_SEG equ 0x1000"],
      [4, "HMA_SEG equ 0xFFFF"],
      [5, "HMA_OFF equ 0x0010"],
      [6, "ENTRY_SEG equ (LOAD_SEG - 1)"],
      [7, "SECTOR_BUF_PARAS equ 0x20"],
      [8, "READ_CACHE_SECTORS equ 4"],
      [9, "READ_CACHE_PARAS equ (SECTOR_BUF_PARAS * READ_CACHE_SECTORS)"],
      [10, "CD_BUF_PARAS equ 0x80"],
      [11, "CD_CACHE_SLOTS equ 4"],
      [12, "%if (CD_CACHE_SLOTS & (CD_CACHE_SLOTS - 1)) != 0"],
      [13, "%error \"CD_CACHE_SLOTS must be a power of two\""],
      [15, "CD_CACHE_SLOT_PARAS equ CD_BUF_PARAS"],
      [16, "SUBDIR_CACHE_SLOTS equ 16"],
      [17, "%if (SUBDIR_CACHE_SLOTS & (SUBDIR_CACHE_SLOTS - 1)) != 0"],
      [20, "SUBDIR_CACHE_SLOT_PARAS equ SECTOR_BUF_PARAS"],
      [21, "CD_BUF equ 0x0180"],
      [22, "SEC_BUF equ 0x0200"],
      [23, "READ_CACHE_BUF equ (SEC_BUF + SECTOR_BUF_PARAS)"],
      [24, "WRITE_CACHE_BUF equ 0x06A0"],
      [25, "CD_CACHE_BUF equ (WRITE_CACHE_BUF + SECTOR_BUF_PARAS)"],
      [26, "SUBDIR_CACHE_BUF equ (CD_CACHE_BUF + (CD_CACHE_SLOTS * CD_CACHE_SLOT_PARAS))"],
      [34, "MCB_START equ 0x0B00"],
      [35, "MEM_TOP equ 0xA000"],
      [36, "ENV_PARAS equ 16"],
      [37, "ENV_SIZE_BYTES equ (ENV_PARAS * 16)"],
      [38, "ENV_OWNER_TEMP equ 0xFFFF"],
      [39, "%if (MEM_TOP & 0xFF) != 0"],
      [40, "%error \"MEM_TOP must be 256-byte aligned\""],
      [42, "MCB_SIG_M equ 'M'"],
      [43, "MCB_SIG_Z equ 'Z'"]],
    hi: [4, 6, 7, 8, 9, 11, 12, 16, 17, 24, 25, 26, 34, 38, 39],
    tests: ["scripts/test_boot.py", "scripts/test_highmcb.py", "scripts/test_free.py"],
  },
  {
    id: "boot",
    title: "Boot installs the initial arena",
    summary: "Relocation, stack placement, XMS sizing, and the first MCB happen before loading a child.",
    body: [
      "The kernel enables the A20 line, copies itself to the HMA at `HMA_SEG:HMA_OFF`, switches DS/ES/SS to the relocated segment, and puts the stack at `KERNEL_STACK_TOP` near the top of the HMA. Only after serial/VGA bring-up and memory reporting does it initialize optional XMS sizing and the DOS arena.",
      "The first arena is a single last-block MCB at `MCB_START`: signature `Z`, owner zero, sized to the BIOS INT 12h conventional-memory line (the EBDA above it stays with the BIOS). Every later allocation is just a split or owner change inside that chain."],
    file: "src/kernel.asm",
    code: [
      [123, "kernel_entry:"],
      [139, "    call enable_a20"],
      [147, "    mov ax, HMA_SEG"],
      [154, "    jmp HMA_SEG:.relocated"],
      [155, ".relocated:"],
      [159, "    mov ss, ax"],
      [160, "    mov sp, KERNEL_STACK_TOP"],
      [171, "    int 0x12"],
      [172, "    mov [mem_kib], ax"],
      [180, "%if ENABLE_XMS"],
      [181, "    call init_xms_size"],
      [197, "    mov ax, MCB_START"],
      [198, "    mov es, ax"],
      [199, "    mov byte [es:0], MCB_SIG_Z"],
      [200, "    mov word [es:1], 0"],
      [203, "    mov ax, [mem_kib]"],
      [205, "    shl ax, cl"],
      [210, "    sub ax, MCB_START + 1"],
      [211, "    mov word [es:3], ax"],
      [211, "    mov word [es:3], ax"],
      [212, "    mov word [mcb_first], MCB_START"],
      [213, "    mov word [cur_psp], 0"]],
    hi: [139, 155, 147, 197, 197, 210, 210],
    tests: ["scripts/test_boot.py", "scripts/test_memfail.py", "scripts/test_highmcb.py"],
  },
  {
    id: "guards",
    title: "Compile-time guards catch overlap",
    summary: "Kernel size and buffer placement are checked before an image can boot.",
    body: [
      "The dangerous edits are not in allocation code; they are usually new kernel code, larger buffers, or an EMS frame moved into the wrong segment. The final assertions in `src/kernel.asm` stop those mistakes at NASM time.",
      "These guards keep the HMA-resident kernel clear of its own stack, keep the image small enough for the boot loader's staging area at `LOAD_SEG`, keep the low FAT/CD/sector/read/root/write/CD-cache/subdirectory-cache buffers ordered, and ensure the cache buffers stay below `MCB_START`."],
    file: "src/kernel.asm",
    code: [
      [4758, "%if (HMA_OFF + (kernel_end - kernel_entry)) > (KERNEL_STACK_TOP - KERNEL_STACK_GUARD_BYTES)"],
      [4759, "%error \"kernel leaves too little HMA stack guard\""],
      [4761, "%if (kernel_end - kernel_entry) > ((MEM_TOP - LOAD_SEG) * 16)"],
      [4762, "%error \"kernel exceeds boot load area\""],
      [4764, "%if (FAT_SEG + 0x120) > CD_BUF"],
      [4765, "%error \"FAT buffer overlaps CD_BUF\""],
      [4767, "%if (CD_BUF + CD_BUF_PARAS) > SEC_BUF"],
      [4768, "%error \"CD_BUF overlaps SEC_BUF\""],
      [4770, "%if (SEC_BUF + SECTOR_BUF_PARAS) > READ_CACHE_BUF"],
      [4771, "%error \"SEC_BUF overlaps READ_CACHE_BUF\""],
      [4773, "%if (READ_CACHE_BUF + READ_CACHE_PARAS) > ROOT_SEG"],
      [4774, "%error \"READ_CACHE_BUF overlaps ROOT_SEG\""],
      [4776, "%if (ROOT_SEG + ROOT_BUF_PARAS) > WRITE_CACHE_BUF"],
      [4777, "%error \"ROOT_SEG overlaps WRITE_CACHE_BUF\""],
      [4779, "%if (WRITE_CACHE_BUF + SECTOR_BUF_PARAS) > MCB_START"],
      [4780, "%error \"WRITE_CACHE_BUF overlaps MCB arena\""],
      [4782, "%if (WRITE_CACHE_BUF + SECTOR_BUF_PARAS) > CD_CACHE_BUF"],
      [4783, "%error \"WRITE_CACHE_BUF overlaps CD cache\""],
      [4785, "%if (CD_CACHE_BUF + (CD_CACHE_SLOTS * CD_CACHE_SLOT_PARAS)) > MCB_START"],
      [4786, "%error \"CD cache overlaps MCB arena\""],
      [4788, "%if (CD_CACHE_BUF + (CD_CACHE_SLOTS * CD_CACHE_SLOT_PARAS)) > SUBDIR_CACHE_BUF"],
      [4789, "%error \"CD cache overlaps subdirectory cache\""],
      [4791, "%if (SUBDIR_CACHE_BUF + (SUBDIR_CACHE_SLOTS * SUBDIR_CACHE_SLOT_PARAS)) > MCB_START"],
      [4792, "%error \"subdirectory cache overlaps MCB arena\""],
      [4794, "%if MCB_START >= MEM_TOP"],
      [4795, "%error \"MCB arena is empty\""],
      [4797, "%if ENABLE_EMS && EMS_FRAME_SEG < 0xD000"],
      [4798, "%error \"EMS frame must use an upper-memory window at D000h or above\""],
      [4809, "%if ENABLE_XMS && XMS_MAX_KB > 15360"],
      [{a: "xms_backing_limit_error"}, "%error \"XMS BIOS move backing must remain below 16 MiB\""]],
    hi: [4758, 4758, 4758, 4758, 4758, 4758, 4758, 4758, 4758, 4761, 4764, 4767, 4770, 4773, 4785],
    tests: ["scripts/test_boot.py", "scripts/test_free.py", "scripts/test_ems.py"],
  },
  {
    id: "mcb",
    title: "MCBs split, merge, and walk by size",
    summary: "Each block has a one-paragraph header before the segment DOS returns.",
    body: [
      "An MCB header starts one paragraph before the usable block. Byte 0 is `M` or `Z`, word 1 is the owner PSP, and word 3 is the block size in paragraphs. The next header is current segment plus size plus one.",
      "`alloc_mem_direct` is the compact helper used by loader-owned internal allocations. It walks from `mcb_first`, chooses the first free block large enough, splits if the remainder can hold another MCB, stamps the owner with `cur_psp`, and returns the usable segment."],
    file: "src/kernel/memory_mcb.inc",
    code: [
      [1, "mcb_walk_next:"],
      [2, "    mov ax, [ds:3]"],
      [5, "    add ax, si"],
      [7, "    inc ax"],
      [9, "    cmp ax, MEM_TOP"],
      [22, "mcb_split_low:"],
      [54, "mcb_split_high:"],
      [83, "mcb_chain_validate:"],
      [102, "alloc_mem_direct:"],
      [86, "    mov si, [cs:mcb_first]"],
      [107, "    MCB_WALK_EACH .amd_walk, .amd_check, .amd_next, .amd_nomem, .amd_nomem, .amd_nomem"],
      [109, "    cmp word [ds:1], 0"],
      [112, "    cmp ax, [cs:am_req]"],
      [29, "    cmp ax, 2"],
      [36, "    mov [es:0], al"],
      [41, "    mov [es:3], cx"],
      [66, "    mov byte [ds:0], MCB_SIG_M"],
      [43, "    mov [ds:3], bx"],
      [115, "    mov ax, [cs:cur_psp]"],
      [116, "    mov word [ds:1], ax"],
      [118, "    inc ax"]],
    hi: [1, 22, 102, 107, 29, 66, 116, 118],
    tests: ["scripts/test_highmcb.py", "scripts/test_envmcb.py", "scripts/test_memrelease.py"],
  },
  {
    id: "strategy",
    title: "DOS allocation strategy is visible",
    summary: "AH=58h selects first, best, or last fit; AH=48h applies it.",
    body: [
      "Programs can query and set the DOS allocation strategy through `INT 21h AH=58h`. LainDOS stores only values 0 through 2, and AH=48h dispatches them straight onto the shared allocators: `alloc_mem_direct` (first fit), `alloc_mem_direct_best`, and `alloc_mem_direct_high` (last fit), after `mcb_chain_validate` has checked every signature.",
      "The default strategy is plain DOS first fit. An earlier build biased tiny requests to the last suitable block, but that deviation handed DOS/4GW's transfer buffer a top-of-memory segment and broke programs that sign-extend real-mode segments (Settlers II's VBE path); real-DOS placement turned out to be the safer behavior."],
    file: "src/kernel/int21.inc",
    code: [
      [1477, ".alloc_strategy:"],
      [1147, "    cmp al, 0"],
      [1491, "    je .as_get"],
      [1149, "    cmp al, 1"],
      [1493, "    je .as_set"],
      [831, "    xor ax, ax"],
      [1550, "    mov al, [cs:alloc_strat]"],
      [1500, "    cmp bl, 2"],
      [1502, "    mov [cs:alloc_strat], bl"],
      [1539, ".alloc_mem:"],
      [1548, "    call mcb_chain_validate"],
      [1553, "    je .am_strat_best"],
      [1555, "    je .am_strat_high"],
      [1556, ".am_strat_first:"],
      [1559, ".am_strat_best:"],
      [1562, ".am_strat_high:"],
      [1598, ".am_nomem:"],
      [1599, "    call find_largest_free_block"],
      [1600, "    mov ax, 8"]],
    hi: [1477, 1502, 1548, 1553, 1559, 1562, 1600],
    tests: ["scripts/test_stratapi.py", "scripts/test_memfail.py", "scripts/test_highmcb.py"],
  },
  {
    id: "free-resize",
    title: "Free and resize repair the chain",
    summary: "AH=49h and AH=4Ah validate headers, split remainders, and merge adjacent free blocks.",
    body: [
      "Freeing a block checks the header immediately before ES, clears its owner, and merges forward if the next block is also free. Resizing uses the same header contract: grow by absorbing the next free block, or shrink by carving a new free MCB after the requested size.",
      "Failure paths return DOS error codes and preserve the original allocation where possible. When allocation fails, BX is filled with the largest free block so callers can retry with a smaller request."],
    file: "src/kernel/int21.inc",
    code: [
      [1626, ".free_mem:"],
      [1632, "    mov si, es"],
      [1633, "    dec si"],
      [1635, "    MCB_IS_VALID"],
      [1635, "    MCB_IS_VALID"],
      [1640, "    mov word [ds:1], 0"],
      [1641, "    call mcb_merge_free_forward"],
      [1648, ".resize_mem:"],
      [1655, "    mov [cs:rm_req], bx"],
      [1632, "    mov si, es"],
      [1664, "    mov ax, [ds:3]"],
      [1666, "    jae .rm_shrink"],
      [1674, "    cmp byte [es:0], MCB_SIG_M"],
      [1679, "    cmp word [es:1], 0"],
      [1683, "    add ax, cx"],
      [1665, "    cmp ax, bx"],
      [1696, "    call mcb_split_low"],
      [1696, "    call mcb_split_low"],
      [1641, "    call mcb_merge_free_forward"],
      [1692, "    mov ax, [ds:3]"],
      [1696, "    call mcb_split_low"],
      [1641, "    call mcb_merge_free_forward"],
      [1716, "    mov [es:0x02], ax"],
      [1725, ".rm_cant_grow:"],
      [1797, "    mov bx, ax"],
      [1727, "    mov ax, 8"]],
    hi: [1632, 1635, 1640, 1640, 1648, 1696, 1725, 1797],
    tests: ["scripts/test_memfail.py", "scripts/test_memrelease.py", "scripts/test_tsr.py"],
  },
  {
    id: "owners",
    title: "Owners make cleanup deterministic",
    summary: "The current PSP owns program blocks, environment blocks, and child allocations.",
    body: [
      "Environment blocks start with a temporary owner while EXEC is still building the child. Once the PSP is committed, `assign_exec_environment_owner` changes the MCB owner to the child PSP, putting it on the same cleanup path as ordinary allocations.",
      "Normal termination clears transient XMS/EMS state, closes handles, walks the MCB chain, releases every block whose owner matches `cur_psp`, then coalesces free neighbors before returning to the parent PSP saved at PSP:16h."],
    file: "src/kernel/exec.inc",
    code: [
      [{a: "alloc_exec_environment_start"}, "alloc_exec_environment:"],
      [737, "    mov word [cs:exec_env_seg], 0"],
      [561, "    mov bx, ENV_PARAS"],
      [743, "    call alloc_mem_direct"],
      [745, "    mov [cs:exec_env_seg], ax"],
      [748, "    dec ax"],
      [749, "    mov ds, ax"],
      [{a: "alloc_exec_environment_temp_owner"}, "    mov word [ds:1], ENV_OWNER_TEMP"],
      [{a: "free_exec_environment_start"}, "free_exec_environment:"],
      [774, "    dec ax"],
      [{a: "free_exec_environment_coalesce"}, "    mov word [ds:1], 0"],
      [793, "assign_exec_environment_owner:"],
      [797, "    mov bx, [cs:exec_env_seg]"],
      [802, "    dec bx"],
      [807, "    mov ax, [cs:cur_psp]"],
      [{a: "env_owner_store"}, "    mov [ds:1], ax"]],
    hi: [{a: "alloc_exec_environment_start"}, {a: "alloc_exec_environment_temp_owner"}, {a: "free_exec_environment_start"}, 793, 807, {a: "env_owner_store"}],
    tests: ["scripts/test_envmcb.py", "scripts/test_execenv.py", "scripts/test_envoflow.py", "scripts/test_memrelease.py"],
  },
  {
    id: "terminate",
    title: "Exit releases process memory",
    summary: "A child can leak only if its owner tag is wrong.",
    body: [
      "Termination is not a wholesale arena reset. It is owner-based: each MCB is checked against the current PSP, matching blocks are marked free, and unrelated parent or resident blocks remain intact.",
      "After the walk, `mcb_coalesce_all_free` merges adjacent free blocks. That is why the shell can run a child repeatedly and still report a stable largest executable block."],
    file: "src/kernel.asm",
    code: [
      [2795, "do_terminate:"],
      [2806, "%if ENABLE_EMS"],
      [4734, "    mov word [cs:ems_alloc_pages], 0"],
      [2809, "    mov word [cs:xms_alloc_kb], 0"],
      [2810, "    call release_inherited_handles"],
      [2811, "    call close_owned_handles"],
      [2813, "    mov si, [cs:mcb_first]"],
      [2814, "    MCB_WALK_EACH .dt_mcb_walk, .dt_mcb_check, .dt_mcb_next, .dt_mcb_done, .dt_mcb_done, .dt_mcb_done"],
      [2752, "    mov ax, [cs:cur_psp]"],
      [2817, "    cmp word [ds:1], ax"],
      [2819, "    mov word [ds:1], 0"],
      [2822, "    call mcb_coalesce_all_free"],
      [2827, "    mov ax, [0x16]"],
      [{a: "do_terminate_restore_parent_psp"}, "    mov [cs:cur_psp], ax"]],
    hi: [2752, 2795, 4734, 2795, 2795, 2795, 2795, 2795, {a: "do_terminate_restore_parent_psp"}],
    tests: ["scripts/test_memrelease.py", "scripts/test_free.py", "scripts/test_shell.py"],
  },
  {
    id: "xms",
    title: "XMS is a single-handle shim",
    summary: "INT 2Fh advertises an XMS entry point backed by BIOS INT 15h moves.",
    body: [
      "On boot, LainDOS asks BIOS `INT 15h AH=88h` for extended memory and caps XMS at `XMS_MAX_KB` when there is enough RAM left for the default EMS pool. `INT 2Fh AX=4300h/4310h` then advertises one XMS entry point for callers that probe HIMEM-style services, and the private `AX=43E0h` subfunction reports the pool size in DX so the FREE utility can show a real XMS total.",
      "The implementation intentionally supports a single allocated handle: allocation succeeds only if no handle is active, handle 1 represents the whole block, and moves validate both real-mode endpoints and XMS offsets before chunking through BIOS `INT 15h AH=87h`."],
    file: "src/kernel.asm",
    code: [
      [45, "%ifndef XMS_MAX_KB"],
      [46, "%define XMS_MAX_KB 15360"],
      [115, "%ifndef ENABLE_XMS"],
      [116, "%define ENABLE_XMS 1"],
      [2035, "init_xms_size:"],
      [2037, "    mov word [cs:xms_total_kb], 0"],
      [2038, "    mov ah, 0x88"],
      [2039, "    int 0x15"],
      [2044, "    call init_xms_store"],
      [4465, "init_xms_store:"],
      [4470, "    cmp ax, (EMS_TOTAL_PAGES * 16)"],
      [4475, "    mov ax, XMS_MAX_KB - 64"],
      [4486, "    mov [cs:ems_backing_hi], bx"],
      [4482, "    mov [cs:xms_total_kb], ax"],
      [2072, "int2f_handler:"],
      [2086, "    cmp ax, 0x4300"],
      [2088, "    cmp ax, 0x4310"],
      [2094, "    mov al, 0x80"],
      [2097, "    mov bx, xms_entry"],
      [2110, "xms_entry:"],
      [2127, "    cmp ah, 0x08"],
      [2129, "    cmp ah, 0x09"],
      [2131, "    cmp ah, 0x0A"],
      [2133, "    cmp ah, 0x0B"],
      [2170, "    mov ax, [cs:xms_total_kb]"],
      [2176, "    cmp word [cs:xms_alloc_kb], 0"],
      [2180, "    cmp dx, [cs:xms_total_kb]"],
      [2182, "    mov [cs:xms_alloc_kb], dx"],
      [2158, "    mov ax, 1"],
      [2147, "    mov dx, 1"],
      [2196, "    mov word [cs:xms_alloc_kb], 0"],
      [2200, ".move:"],
      [2209, "    test ax, 1"],
      [2217, "    call xms_prepare_endpoint"],
      [2225, "    call xms_prepare_endpoint"],
      [2271, "    mov ax, 0x8700"],
      [{a: "xms_move_bios_call"}, "    int 0x15"]],
    hi: [45, 115, 2035, 4465, 2086, 2094, 2110, 2170, 2196, {a: "xms_move_bios_call"}],
    tests: ["scripts/test_xms.py", "scripts/test_free.py", "scripts/test_shell.py"],
  },
  {
    id: "ems",
    title: "EMS is default with an upper frame",
    summary: "Normal builds install INT 67h with 16 handles, four page-frame slots, and a 6 MiB backing pool when the D000h frame probe succeeds.",
    body: [
      "EMS needs a 64 KiB page frame, but putting that frame in conventional memory would make Millennia-style 580 KiB base-memory checks impossible. LainDOS therefore enables and probes PCI shadow RAM for a `D000h` upper-memory frame before advertising EMS.",
      "The default EMS driver exposes 16 handles, 384 logical pages (6 MiB), and four physical page-frame slots. Mapping saves the old frame page back to high backing storage, copies the requested logical page into the frame, and records the mapping. The backing base is computed after XMS sizing so EMS and XMS do not alias."],
    file: "src/kernel.asm",
    code: [
      [48, "XMS_BASE_HI equ 0x0011"],
      [49, "EMS_TOTAL_PAGES equ 384"],
      [50, "%ifndef EMS_FRAME_SEG"],
      [51, "%define EMS_FRAME_SEG 0xD000"],
      [53, "EMS_FRAME_PARAS equ 0x1000"],
      [119, "%ifndef ENABLE_EMS"],
      [120, "%define ENABLE_EMS 1"],
      [1840, "%if ENABLE_EMS"],
      [1841, "    mov [es:0x67*4], word int67_handler"],
      [1843, "%else"],
      [1844, "    mov [es:0x67*4], word int67_absent_handler"],
      [2429, "%if !ENABLE_EMS"],
      [2430, "int67_absent_handler:"],
      [2431, "    mov ah, 0x80"],
      [2435, "%if ENABLE_EMS"],
      [2436, "EMS_MAX_HANDLES equ 16"],
      [2438, "int67_handler:"],
      [2476, ".frame:"],
      [2478, "    mov bx, EMS_FRAME_SEG"],
      [2480, ".pages:"],
      [2481, "    mov bx, [cs:ems_total_pages]"],
      [2486, ".alloc:"],
      [2489, "    mov ax, [cs:ems_total_pages]"],
      [2490, "    sub ax, [cs:ems_alloc_pages]"],
      [2491, "    cmp bx, ax"],
      [2493, "    call ems_find_free_handle"],
      [2495, "    call ems_find_page_run"],
      [2497, "    mov [cs:si+ems_handle_pages], bx"],
      [2498, "    mov [cs:si+ems_handle_base], ax"],
      [2499, "    add [cs:ems_alloc_pages], bx"],
      [2509, ".map:"],
      [2510, "    call ems_handle_offset"],
      [2512, "    cmp al, 3"],
      [2514, "    cmp bx, [cs:si+ems_handle_pages]"],
      [2516, "    push bx"],
      [2517, "    add bx, [cs:si+ems_handle_base]"],
      [2526, "    cmp bx, [cs:si+ems_map_pages]"],
      [2528, "    je .map_already"],
      [2552, "    call ems_copy_16k"],
      [2570, "    mov [cs:si+ems_map_pages], bx"],
      [2581, ".map_already:"],
      [2599, ".free:"],
      [2602, "    call ems_clear_handle_maps"],
      [2603, "    mov ax, [cs:si+ems_handle_base]"],
      [2605, "    call ems_clear_owner_pages"],
      [2606, "    sub [cs:ems_alloc_pages], bx"],
      [2616, "    mov bx, EMS_MAX_HANDLES"],
      [2621, "    mov bx, [cs:si+ems_handle_pages]"],
      [4734, "    mov word [cs:ems_alloc_pages], 0"],
      [4735, "    mov di, ems_handle_pages"],
      [4738, "    mov di, ems_handle_base"],
      [4741, "    mov di, ems_page_owner"],
      [2666, "ems_clear_map:"],
      [{a: "ems_clear_map_fill"}, "    mov word [cs:ems_map_pages], 0xFFFF"]],
    hi: [119, 1840, 2429, 2431, 2481, 2490, 2491, 2493, 2495, 2509, 2510, 2512, 2526, 2581, 2599, 2599, 2603, 2616, 4734, 4734, 4734],
    tests: ["scripts/test_ems.py", "scripts/test_emsmulti.py", "scripts/test_emspreserve.py", "scripts/test_emsmem.py", "scripts/test_emslarge.py", "scripts/test_emsxms.py"],
  },
  {
    id: "report",
    title: "FREE.COM is the user-visible audit",
    summary: "The shell memory report walks the same MCB chain users depend on.",
    body: [
      "The FREE utility first moves its stack into the image and shrinks its own COM block, so its large inherited allocation does not hide all free conventional memory. It then starts at `MCB_START`, validates each header, totals free paragraphs, records the largest free block, probes XMS via INT 2Fh, probes EMS via INT 67h, and prints the table the tests inspect.",
      "This gives contributors a quick manual sanity check after memory-sensitive changes: if MCB headers are corrupt, largest executable size is wrong, or XMS/EMS totals become inconsistent, `make test` and the shell `MEM`/FREE path should catch it."],
    file: "programs/free.asm",
    code: [
      [4, "%include \"src/memory.inc\""],
      [6, "CONV_TOTAL_KB equ (MEM_TOP / 64)"],
      [15, "    mov sp, free_stack_top"],
      [19, "    mov bx, free_resident_paras"],
      [20, "    mov ah, 0x4A"],
      [21, "    int 0x21"],
      [22, "    jc resize_failed"],
      [26, "    call collect_mcb"],
      [27, "    call query_xms"],
      [28, "    call query_ems"],
      [35, "collect_mcb:"],
      [40, "    mov si, MCB_START"],
      [44, "    cmp si, MEM_TOP"],
      [48, "    cmp al, MCB_SIG_M"],
      [50, "    cmp al, MCB_SIG_Z"],
      [59, "    mov ax, [1]"],
      [61, "    mov ax, [3]"],
      [65, "    cmp word [block_owner], 0"],
      [68, "    add [free_paras], ax"],
      [69, "    cmp ax, [largest_free]"],
      [73, "    cmp byte [block_sig], MCB_SIG_Z"],
      [77, "    add ax, [block_size]"],
      [85, "query_xms:"],
      [90, "    mov ax, 0x4300"],
      [91, "    int 0x2F"],
      [101, "    mov ah, 0x08"],
      [102, "    call far [xms_entry]"],
      [116, "query_ems:"],
      [120, "    mov ah, 0x40"],
      [121, "    int 0x67"],
      [124, "    mov ah, 0x42"],
      [125, "    int 0x67"]],
    hi: [15, 19, 20, 22, 26, 35, 40, 48, 65, 68, 85, 116],
    tests: ["scripts/test_free.py", "scripts/test_shell.py", "scripts/test_xms.py", "scripts/test_ems.py"],
  }];

const MEM_TESTS = [
  ["High MCB", "scripts/test_highmcb.py", "Checks high-biased small allocations and resulting MCB layout."],
  ["Strategy", "scripts/test_stratapi.py", "Pins AH=58h get/set plus first, best, and last-fit behavior."],
  ["Failure", "scripts/test_memfail.py", "Verifies allocation failure, largest-free returns, invalid free, and resize errors."],
  ["Release", "scripts/test_memrelease.py", "Runs a child and confirms process-owned memory is reclaimed."],
  ["Shell floor", "scripts/test_shellmem.py", "Checks a shell-launched child receives at least 580 KiB despite the resident shell."],
  ["XMS", "scripts/test_xms.py", "Exercises INT 2Fh discovery, single-handle allocation, moves, bounds, and free."],
  ["EMS", "scripts/test_ems.py", "Tests default EMS status, device detection, frame/page mapping, and release."],
  ["EMS handles", "scripts/test_emsmulti.py", "Checks two EMS handles map to distinct backing pages."],
  ["EMS registers", "scripts/test_emspreserve.py", "Checks EMS calls preserve caller registers except documented return values."],
  ["Env MCB", "scripts/test_envmcb.py", "Confirms EXEC environment blocks get child PSP ownership."],
  ["FREE", "scripts/test_free.py", "Checks user-visible memory totals, largest executable block, XMS, and EMS lines."]];

function MemoryPage({ go }) {
  const T = window.T;
  return (
    <div style={{ minHeight: "100vh", background: T.bg }}>
      <header className="hero-bg" style={{ padding: "56px 56px 46px" }}>
        <div style={{ maxWidth: 1120, margin: "0 auto" }}>
          <div style={{ display: "flex", alignItems: "center", gap: 10, fontFamily: "'IBM Plex Mono', monospace",
            fontSize: 12, color: "#ffe1c0", letterSpacing: 2, textTransform: "uppercase" }}>
            <span style={{ width: 8, height: 8, borderRadius: "50%", background: "#7ee0d4", flex: "0 0 auto" }} /> Real-mode memory track
          </div>
          <h1 style={{ fontFamily: "'Newsreader', serif", fontSize: 76, lineHeight: "76px", fontWeight: 500, margin: "12px 0 16px",
            color: "#fff", textShadow: "2px 2px 0 rgba(0,0,0,0.25)" }}>
            Memory
          </h1>
          <p style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", color: "rgba(255,255,255,0.92)", fontSize: 17,
            lineHeight: 1.65, maxWidth: 790, margin: 0 }}>
            How LainDOS fits a kernel, filesystem buffers, a DOS MCB arena, optional EMS frame,
            and XMS shims into a real-mode machine that still has to run games below 640K.
          </p>
        </div>
      </header>

      <div style={{ maxWidth: 1120, margin: "0 auto", padding: "34px 56px 60px" }}>
        <div className="site-two-col" style={{ display: "grid", gridTemplateColumns: "1fr 320px", gap: 30, alignItems: "start" }}>
          <div>
            <section style={memCard(T)}>
              <h2 style={memH2(T)}>The memory path</h2>
              <p style={memP(T)}>
                LainDOS is small enough to explain as a map. The kernel and its fixed buffers live below
                the program arena; DOS allocations are MCB headers linked by paragraph counts; child exit
                is just owner cleanup plus coalescing. The hard part is not the algorithm, it is keeping
                every fixed segment from colliding as the kernel grows.
              </p>
              <div style={{ display: "grid", gap: 10, marginTop: 14 }}>
                {MEM_FLOW.map((row, i) => <MemFlow key={row[0]} row={row} index={i} />)}
              </div>
            </section>

            {MEM_SECTIONS.map(section => <MemSection key={section.id} section={section} />)}
          </div>

          <aside className="site-boot-side" style={{ position: "sticky", top: 24 }}>
            <div style={memPanel(T)}>
              <h3 style={memKicker(T)}>Segment map</h3>
              <window.MemoryMap touches={["ivt", "bda", "fat", "kernel", "sec", "cache", "write", "root", "arena", "vga"]} compact={true} />
              <div style={{ display: "grid", gap: 8, marginTop: 12 }}>
                {MEM_REGIONS.map(row => <MemRegion key={row[0]} row={row} />)}
              </div>
            </div>
            <div style={{ ...memPanel(T), marginTop: 14 }}>
              <h3 style={memKicker(T)}>Regression map</h3>
              <div style={{ display: "grid", gap: 9 }}>
                {MEM_TESTS.map(row => <MemTest key={row[0]} row={row} />)}
              </div>
            </div>
            <div style={{ ...memPanel(T), marginTop: 14 }}>
              <h3 style={memKicker(T)}>Related tracks</h3>
              <button onClick={() => go("boot/s5")} style={{ ...memButton(T.pink), marginBottom: 8 }}>Boot arena setup</button>
              <button onClick={() => go("prog")} style={{ ...memButton(T.amber), marginBottom: 8 }}>Program loading</button>
              <button onClick={() => go("tests")} style={memButton(T.blue)}>Test ladder</button>
            </div>
          </aside>
        </div>
      </div>
    </div>
  );
}

function MemFlow({ row, index }) {
  const T = window.T;
  return (
    <div style={{ display: "grid", gridTemplateColumns: "42px 110px 1fr", gap: 12, alignItems: "baseline",
      border: `1px solid ${T.line}`, borderRadius: 10, background: "#fffdf6", padding: "10px 12px" }}>
      <code style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 12, color: T.faint }}>{String(index + 1).padStart(2, "0")}</code>
      <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 12, color: T.pink, textTransform: "uppercase" }}>{row[0]}</div>
      <div style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 13.5, color: T.dim, lineHeight: 1.5 }}><window.InlineText text={row[1]} /></div>
    </div>
  );
}

function MemSection({ section }) {
  const T = window.T;
  return (
    <section id={section.id} style={{ borderTop: `1px solid ${T.line}`, padding: "28px 0" }}>
      <div style={{ display: "flex", alignItems: "baseline", gap: 10, flexWrap: "wrap", marginBottom: 8 }}>
        <h2 style={{ ...memH2(T), margin: 0 }}>{section.title}</h2>
        <code style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 11.5, color: T.pink }}>{section.summary}</code>
      </div>
      {section.body.map((p, i) => <p key={i} style={memP(T)}><window.InlineText text={p} /></p>)}
      <div style={{ display: "grid", gap: 14, marginTop: 16, alignItems: "start" }}>
        <window.CodeBlock file={section.file} code={section.code} hi={section.hi} />
        <div style={{ display: "grid", gap: 12 }}>
          <div style={memPanel(T)}>
            <h3 style={memKicker(T)}>Tests that pin this</h3>
            <div style={{ display: "grid", gap: 7 }}>
              {section.tests.map(test => <code key={test} style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 11.5, color: T.blue }}>{test}</code>)}
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

function MemRegion({ row }) {
  const T = window.T;
  return (
    <div style={{ border: `1px solid ${T.line}`, borderRadius: 8, background: "#fffdf6", padding: "9px 10px" }}>
      <code style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 11.5, color: T.pink }}>{row[0]}</code>
      <div style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 12.5, color: T.dim, lineHeight: 1.45, marginTop: 3 }}><window.InlineText text={row[1]} /></div>
    </div>
  );
}

function MemTest({ row }) {
  const T = window.T;
  return (
    <div style={{ border: `1px solid ${T.line}`, borderRadius: 8, background: "#fffdf6", padding: "10px 11px" }}>
      <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 11.5, color: T.pink, textTransform: "uppercase" }}>{row[0]}</div>
      <code style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 11.5, color: T.blue }}>{row[1]}</code>
      <div style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 12.5, color: T.dim, lineHeight: 1.45, marginTop: 4 }}><window.InlineText text={row[2]} /></div>
    </div>
  );
}

function memCard(T) {
  return { border: `1px solid ${T.line}`, borderRadius: 12, background: T.panel, padding: "18px 20px", marginBottom: 22 };
}
function memPanel(T) {
  return { border: `1px solid ${T.line}`, borderRadius: 12, background: T.panel, padding: "14px" };
}
function memH2(T) {
  return { fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 25, lineHeight: 1.2, color: T.ink, margin: "0 0 10px" };
}
function memP(T) {
  return { fontFamily: "'Zen Kaku Gothic New', sans-serif", color: T.dim, fontSize: 15.5, lineHeight: 1.65, maxWidth: 760, margin: "0 0 12px" };
}
function memKicker(T) {
  return { fontFamily: "'IBM Plex Mono', monospace", fontSize: 11, letterSpacing: 1.5, textTransform: "uppercase", color: T.dim, margin: "0 0 9px" };
}
function memButton(c) {
  return { background: "transparent", color: c, border: `1px solid ${c}`, borderRadius: 8, padding: "10px 13px",
    fontFamily: "'IBM Plex Mono', monospace", fontSize: 12.5, cursor: "pointer", width: "100%" };
}

Object.assign(window, { MemoryPage });
