const MEM_FLOW = [
  ["Layout", "The kernel relocates to the HMA at FFFF:0010, keeps scratch buffers below 0660h, and reserves A000h for VGA."],
  ["Arena", "One free MCB starts at 0B00h and grows upward until MEM_TOP, with owner 0 meaning free."],
  ["Allocate", "INT 21h AH=48h supports first, best, and last-fit strategy, plus a high-biased small allocation path."],
  ["Own", "Program and environment blocks are stamped with the current PSP so exit cleanup can reclaim them."],
  ["Extend", "XMS is a single-handle BIOS-move shim; EMS is optional and disabled in normal builds."]];

const MEM_REGIONS = [
  ["0000:0000", "IVT and BIOS data remain in low memory because hardware and BIOS calls still own them."],
  ["0060:0000", "FAT_SEG scratch space holds the resident FAT image and is reused by FAT12/FAT16 logic."],
  ["0180:0000", "CD_BUF is the 2 KiB ISO9660 sector buffer for the CD-ROM driver."],
  ["0200:0000", "SEC_BUF and READ_CACHE_BUF are fixed one-sector buffers used by loader and filesystem paths."],
  ["0240:0000", "ROOT_SEG holds the resident root directory image."],
  ["0640:0000", "WRITE_CACHE_BUF is the one-sector hard-disk write-back buffer."],
  ["0B00:0000", "MCB_START begins the DOS arena for programs, PSPs, environments, and normal allocations."],
  ["9000:0000", "Optional EMS frame default; enabled only with ENABLE_EMS=1 and guarded against ROM/VGA overlap."],
  ["A000:0000", "MEM_TOP and VGA graphics memory; conventional allocations must stop before this segment."],
  ["FFFF:0010", "The High Memory Area holds the kernel image and stack; the A20 line is enabled at boot and kept on."]];

const MEM_SECTIONS = [
  {
    id: "constants",
    title: "Fixed segments define the machine",
    summary: "The low-memory layout is a contract, not a suggestion.",
    body: [
      "`src/memory.inc` is the first file to read before moving buffers. These equates decide where the boot sector loads the kernel, where the kernel relocates (the High Memory Area at FFFF:0010), where CD/FAT/write-cache scratch sectors live, where the DOS arena begins, and where conventional memory ends.",
      "With the kernel image and stack resident in the HMA, low memory holds only the filesystem scratch buffers: the DOS arena starts at 0B00h — kept at the lowest placement real MS-DOS could produce, because era programs (MONKEY2.EXE among them) corrupt themselves when loaded below that — and VGA graphics memory begins at A000h. `MEM_TOP` must stay 256-byte aligned because several bounds checks compare segment values directly."],
    file: "src/memory.inc",
    code: [
      [3, "LOAD_SEG equ 0x1000"],
      [4, "HMA_SEG equ 0xFFFF"],
      [5, "HMA_OFF equ 0x0010"],
      [6, "ENTRY_SEG equ (LOAD_SEG - 1)"],
      [7, "SECTOR_BUF_PARAS equ 0x20"],
      [8, "CD_BUF_PARAS equ 0x80"],
      [9, "CD_BUF equ 0x0180"],
      [10, "SEC_BUF equ 0x0200"],
      [11, "READ_CACHE_BUF equ (SEC_BUF + SECTOR_BUF_PARAS)"],
      [12, "WRITE_CACHE_BUF equ 0x0640"],
      [20, "MCB_START equ 0x0B00"],
      [21, "MEM_TOP equ 0xA000"],
      [22, "ENV_PARAS equ 16"],
      [23, "ENV_SIZE_BYTES equ (ENV_PARAS * 16)"],
      [24, "ENV_OWNER_TEMP equ 0xFFFF"],
      [25, "%if (MEM_TOP & 0xFF) != 0"],
      [26, "%error \"MEM_TOP must be 256-byte aligned\""],
      [28, "MCB_SIG_M equ 'M'"],
      [29, "MCB_SIG_Z equ 'Z'"]],
    hi: [4, 6, 7, 8, 9, 12, 20, 24, 25],
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
      [120, "kernel_entry:"],
      [136, "    call enable_a20"],
      [144, "    mov ax, HMA_SEG"],
      [151, "    jmp HMA_SEG:.relocated"],
      [152, ".relocated:"],
      [156, "    mov ss, ax"],
      [157, "    mov sp, KERNEL_STACK_TOP"],
      [168, "    int 0x12"],
      [169, "    mov [mem_kib], ax"],
      [177, "%if ENABLE_XMS"],
      [178, "    call init_xms_size"],
      [194, "    mov ax, MCB_START"],
      [195, "    mov es, ax"],
      [196, "    mov byte [es:0], MCB_SIG_Z"],
      [197, "    mov word [es:1], 0"],
      [200, "    mov ax, [mem_kib]"],
      [202, "    shl ax, cl"],
      [207, "    sub ax, MCB_START + 1"],
      [208, "    mov word [es:3], ax"],
      [208, "    mov word [es:3], ax"],
      [209, "    mov word [mcb_first], MCB_START"],
      [210, "    mov word [cur_psp], 0"]],
    hi: [136, 157, 144, 195, 197, 208, 209],
    tests: ["scripts/test_boot.py", "scripts/test_memfail.py", "scripts/test_highmcb.py"],
  },
  {
    id: "guards",
    title: "Compile-time guards catch overlap",
    summary: "Kernel size and buffer placement are checked before an image can boot.",
    body: [
      "The dangerous edits are not in allocation code; they are usually new kernel code, larger buffers, or an EMS frame moved into the wrong segment. The final assertions in `src/kernel.asm` stop those mistakes at NASM time.",
      "These guards keep the HMA-resident kernel clear of its own stack, keep the image small enough for the boot loader's staging area at `LOAD_SEG`, keep the low FAT/CD/sector/read/root/write-cache buffers ordered, and ensure the write cache stays below `MCB_START`."],
    file: "src/kernel.asm",
    code: [
      [4241, "%if (HMA_OFF + (kernel_end - kernel_entry)) > (KERNEL_STACK_TOP - KERNEL_STACK_GUARD_BYTES)"],
      [4242, "%error \"kernel leaves too little HMA stack guard\""],
      [4244, "%if (kernel_end - kernel_entry) > ((MEM_TOP - LOAD_SEG) * 16)"],
      [4245, "%error \"kernel exceeds boot load area\""],
      [4247, "%if (FAT_SEG + 0x120) > CD_BUF"],
      [4248, "%error \"FAT buffer overlaps CD_BUF\""],
      [4250, "%if (CD_BUF + CD_BUF_PARAS) > SEC_BUF"],
      [4251, "%error \"CD_BUF overlaps SEC_BUF\""],
      [4253, "%if (SEC_BUF + SECTOR_BUF_PARAS) > READ_CACHE_BUF"],
      [4254, "%error \"SEC_BUF overlaps READ_CACHE_BUF\""],
      [4256, "%if (READ_CACHE_BUF + SECTOR_BUF_PARAS) > ROOT_SEG"],
      [4257, "%error \"READ_CACHE_BUF overlaps ROOT_SEG\""],
      [4259, "%if (ROOT_SEG + ROOT_BUF_PARAS) > WRITE_CACHE_BUF"],
      [4260, "%error \"ROOT_SEG overlaps WRITE_CACHE_BUF\""],
      [4262, "%if (WRITE_CACHE_BUF + SECTOR_BUF_PARAS) > MCB_START"],
      [4263, "%error \"WRITE_CACHE_BUF overlaps MCB arena\""],
      [4265, "%if MCB_START >= MEM_TOP"],
      [4266, "%error \"MCB arena is empty\""],
      [4268, "%if ENABLE_EMS && EMS_FRAME_SEG <= MCB_START"],
      [4269, "%error \"EMS frame must be inside conventional arena\""],
      [4280, "%if ENABLE_XMS && XMS_MAX_KB > 15360"],
      [{a: "xms_backing_limit_error"}, "%error \"XMS BIOS move backing must remain below 16 MiB\""]],
    hi: [4241, 4244, 4247, 4241, 4241, 4241, 4244, 4247, 4241, 4280],
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
      [1478, ".alloc_strategy:"],
      [1148, "    cmp al, 0"],
      [1492, "    je .as_get"],
      [1150, "    cmp al, 1"],
      [1494, "    je .as_set"],
      [832, "    xor ax, ax"],
      [1551, "    mov al, [cs:alloc_strat]"],
      [1501, "    cmp bl, 2"],
      [1503, "    mov [cs:alloc_strat], bl"],
      [1540, ".alloc_mem:"],
      [1549, "    call mcb_chain_validate"],
      [1554, "    je .am_strat_best"],
      [1556, "    je .am_strat_high"],
      [1557, ".am_strat_first:"],
      [1560, ".am_strat_best:"],
      [1563, ".am_strat_high:"],
      [1599, ".am_nomem:"],
      [1600, "    call find_largest_free_block"],
      [1601, "    mov ax, 8"]],
    hi: [1478, 1503, 1540, 1549, 1557, 1563, 1600],
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
      [1627, ".free_mem:"],
      [1633, "    mov si, es"],
      [1634, "    dec si"],
      [1636, "    MCB_IS_VALID"],
      [1636, "    MCB_IS_VALID"],
      [1641, "    mov word [ds:1], 0"],
      [1642, "    call mcb_merge_free_forward"],
      [1649, ".resize_mem:"],
      [1656, "    mov [cs:rm_req], bx"],
      [1633, "    mov si, es"],
      [1665, "    mov ax, [ds:3]"],
      [1667, "    jae .rm_shrink"],
      [1675, "    cmp byte [es:0], MCB_SIG_M"],
      [1680, "    cmp word [es:1], 0"],
      [1684, "    add ax, cx"],
      [1666, "    cmp ax, bx"],
      [1697, "    call mcb_split_low"],
      [1697, "    call mcb_split_low"],
      [1642, "    call mcb_merge_free_forward"],
      [1693, "    mov ax, [ds:3]"],
      [1697, "    call mcb_split_low"],
      [1642, "    call mcb_merge_free_forward"],
      [1717, "    mov [es:0x02], ax"],
      [1726, ".rm_cant_grow:"],
      [1798, "    mov bx, ax"],
      [1728, "    mov ax, 8"]],
    hi: [1627, 1636, 1641, 1642, 1649, 1697, 1717, 1798],
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
      [736, "    mov word [cs:exec_env_seg], 0"],
      [560, "    mov bx, ENV_PARAS"],
      [742, "    call alloc_mem_direct"],
      [744, "    mov [cs:exec_env_seg], ax"],
      [747, "    dec ax"],
      [748, "    mov ds, ax"],
      [{a: "alloc_exec_environment_temp_owner"}, "    mov word [ds:1], ENV_OWNER_TEMP"],
      [{a: "free_exec_environment_start"}, "free_exec_environment:"],
      [747, "    dec ax"],
      [{a: "free_exec_environment_coalesce"}, "    mov word [ds:1], 0"],
      [792, "assign_exec_environment_owner:"],
      [796, "    mov bx, [cs:exec_env_seg]"],
      [801, "    dec bx"],
      [806, "    mov ax, [cs:cur_psp]"],
      [{a: "env_owner_store"}, "    mov [ds:1], ax"]],
    hi: [{a: "alloc_exec_environment_start"}, {a: "alloc_exec_environment_temp_owner"}, {a: "free_exec_environment_start"}, 792, 806, {a: "env_owner_store"}],
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
      [2673, "do_terminate:"],
      [2683, "%if ENABLE_EMS"],
      [2540, "    mov word [cs:ems_alloc_pages], 0"],
      [2687, "    mov word [cs:xms_alloc_kb], 0"],
      [2688, "    call release_inherited_handles"],
      [2689, "    call close_owned_handles"],
      [2691, "    mov si, [cs:mcb_first]"],
      [2750, "    mov ds, si"],
      [2649, "    mov ax, [cs:cur_psp]"],
      [2695, "    cmp word [ds:1], ax"],
      [2697, "    mov word [ds:1], 0"],
      [2692, "    MCB_WALK_EACH .dt_mcb_walk, .dt_mcb_check, .dt_mcb_next, .dt_mcb_done, .dt_mcb_done, .dt_mcb_done"],
      [2700, "    call mcb_coalesce_all_free"],
      [2705, "    mov ax, [0x16]"],
      [{a: "do_terminate_restore_parent_psp"}, "    mov [cs:cur_psp], ax"]],
    hi: [2673, 2683, 2683, 2683, 2673, 2688, {a: "do_terminate_restore_parent_psp"}],
    tests: ["scripts/test_memrelease.py", "scripts/test_free.py", "scripts/test_shell.py"],
  },
  {
    id: "xms",
    title: "XMS is a single-handle shim",
    summary: "INT 2Fh advertises an XMS entry point backed by BIOS INT 15h moves.",
    body: [
      "On boot, LainDOS asks BIOS `INT 15h AH=88h` for extended memory and caps it at `XMS_MAX_KB`. `INT 2Fh AX=4300h/4310h` then advertises one XMS entry point for callers that probe HIMEM-style services, and the private `AX=43E0h` subfunction reports the pool size in DX so the FREE utility can show a real XMS total.",
      "The implementation intentionally supports a single allocated handle: allocation succeeds only if no handle is active, handle 1 represents the whole block, and moves validate both real-mode endpoints and XMS offsets before chunking through BIOS `INT 15h AH=87h`."],
    file: "src/kernel.asm",
    code: [
      [42, "%ifndef XMS_MAX_KB"],
      [43, "%define XMS_MAX_KB 15360"],
      [112, "%ifndef ENABLE_XMS"],
      [113, "%define ENABLE_XMS 1"],
      [2017, "init_xms_size:"],
      [2019, "    mov word [cs:xms_total_kb], 0"],
      [2020, "    mov ah, 0x88"],
      [2021, "    int 0x15"],
      [2026, "    cmp ax, XMS_MAX_KB - 64"],
      [2028, "    mov ax, XMS_MAX_KB - 64"],
      [2030, "    mov [cs:xms_total_kb], ax"],
      [2052, "int2f_handler:"],
      [2064, "    cmp ax, 0x4300"],
      [2066, "    cmp ax, 0x4310"],
      [2072, "    mov al, 0x80"],
      [2075, "    mov bx, xms_entry"],
      [2088, "xms_entry:"],
      [2105, "    cmp ah, 0x08"],
      [2107, "    cmp ah, 0x09"],
      [2109, "    cmp ah, 0x0A"],
      [2111, "    cmp ah, 0x0B"],
      [2148, "    mov ax, [cs:xms_total_kb]"],
      [2154, "    cmp word [cs:xms_alloc_kb], 0"],
      [2158, "    cmp dx, [cs:xms_total_kb]"],
      [2160, "    mov [cs:xms_alloc_kb], dx"],
      [2136, "    mov ax, 1"],
      [2125, "    mov dx, 1"],
      [2174, "    mov word [cs:xms_alloc_kb], 0"],
      [2178, ".move:"],
      [2187, "    test ax, 1"],
      [2195, "    call xms_prepare_endpoint"],
      [2195, "    call xms_prepare_endpoint"],
      [2249, "    mov ax, 0x8700"],
      [{a: "xms_move_bios_call"}, "    int 0x15"]],
    hi: [43, 113, 2017, 2064, 2075, 2088, 2154, 2174, {a: "xms_move_bios_call"}],
    tests: ["scripts/test_xms.py", "scripts/test_free.py", "scripts/test_shell.py"],
  },
  {
    id: "ems",
    title: "EMS is optional and off by default",
    summary: "Normal builds report no EMS; EMS test builds install INT 67h with one handle and four page-frame slots.",
    body: [
      "EMS needs a 64 KiB page frame in conventional memory, so the default build leaves `ENABLE_EMS` at zero. In that mode, INT 67h returns AH=80h, which lets callers treat EMS as absent without consuming arena space.",
      "When built with `ENABLE_EMS=1`, LainDOS exposes one handle, up to 64 logical pages, and four physical page-frame slots. Mapping saves the old frame page back to high backing storage, copies the requested logical page into the frame, and records the mapping."],
    file: "src/kernel.asm",
    code: [
      [45, "EMS_TOTAL_PAGES equ 64"],
      [46, "%ifndef EMS_FRAME_SEG"],
      [47, "%define EMS_FRAME_SEG 0x9000"],
      [49, "EMS_FRAME_PARAS equ 0x1000"],
      [52, "EMS_BACKING_HI equ 0x0020"],
      [116, "%ifndef ENABLE_EMS"],
      [117, "%define ENABLE_EMS 0"],
      [1817, "%if ENABLE_EMS"],
      [1818, "    mov [es:0x67*4], word int67_handler"],
      [1820, "%else"],
      [1821, "    mov [es:0x67*4], word int67_absent_handler"],
      [2406, "%if !ENABLE_EMS"],
      [2407, "int67_absent_handler:"],
      [2408, "    mov ah, 0x80"],
      [2412, "%if ENABLE_EMS"],
      [2413, "int67_handler:"],
      [2437, ".frame:"],
      [2439, "    mov bx, EMS_FRAME_SEG"],
      [2441, ".pages:"],
      [2442, "    mov bx, EMS_TOTAL_PAGES"],
      [2447, ".alloc:"],
      [2452, "    cmp bx, EMS_TOTAL_PAGES"],
      [2454, "    mov [cs:ems_alloc_pages], bx"],
      [2462, ".map:"],
      [2467, "    cmp al, 3"],
      [2469, "    cmp bx, [cs:ems_alloc_pages]"],
      [2494, "    call ems_copy_16k"],
      [2494, "    call ems_copy_16k"],
      [2512, "    mov [cs:si+ems_map_pages], bx"],
      [2540, "    mov word [cs:ems_alloc_pages], 0"],
      [2564, "ems_clear_map:"],
      [{a: "ems_clear_map_fill"}, "    mov word [cs:ems_map_pages], 0xFFFF"]],
    hi: [117, 1817, 2407, 2413, 2437, 2452, 2452, 2413, 2512],
    tests: ["scripts/test_ems.py", "scripts/test_free.py", "scripts/test_shell.py"],
  },
  {
    id: "report",
    title: "FREE.COM is the user-visible audit",
    summary: "The shell memory report walks the same MCB chain users depend on.",
    body: [
      "The FREE utility is intentionally simple: it starts at `MCB_START`, validates each header, totals free paragraphs, records the largest free block, probes XMS via INT 2Fh, probes EMS via INT 67h, and prints the table the tests inspect.",
      "This gives contributors a quick manual sanity check after memory-sensitive changes: if MCB headers are corrupt, largest executable size is wrong, or XMS/EMS totals become inconsistent, `make test` and the shell `MEM`/FREE path should catch it."],
    file: "programs/free.asm",
    code: [
      [4, "%include \"src/memory.inc\""],
      [6, "CONV_TOTAL_KB equ (MEM_TOP / 64)"],
      [13, "    call collect_mcb"],
      [14, "    call query_xms"],
      [15, "    call query_ems"],
      [22, "collect_mcb:"],
      [27, "    mov si, MCB_START"],
      [31, "    cmp si, MEM_TOP"],
      [35, "    cmp al, MCB_SIG_M"],
      [37, "    cmp al, MCB_SIG_Z"],
      [46, "    mov ax, [1]"],
      [48, "    mov ax, [3]"],
      [52, "    cmp word [block_owner], 0"],
      [55, "    add [free_paras], ax"],
      [56, "    cmp ax, [largest_free]"],
      [60, "    cmp byte [block_sig], MCB_SIG_Z"],
      [64, "    add ax, [block_size]"],
      [72, "query_xms:"],
      [77, "    mov ax, 0x4300"],
      [78, "    int 0x2F"],
      [88, "    mov ah, 0x08"],
      [89, "    call far [xms_entry]"],
      [103, "query_ems:"],
      [107, "    mov ah, 0x40"],
      [108, "    int 0x67"],
      [111, "    mov ah, 0x42"],
      [112, "    int 0x67"]],
    hi: [13, 22, 27, 35, 52, 55, 72, 103],
    tests: ["scripts/test_free.py", "scripts/test_shell.py", "scripts/test_xms.py", "scripts/test_ems.py"],
  }];

const MEM_TESTS = [
  ["High MCB", "scripts/test_highmcb.py", "Checks high-biased small allocations and resulting MCB layout."],
  ["Strategy", "scripts/test_stratapi.py", "Pins AH=58h get/set plus first, best, and last-fit behavior."],
  ["Failure", "scripts/test_memfail.py", "Verifies allocation failure, largest-free returns, invalid free, and resize errors."],
  ["Release", "scripts/test_memrelease.py", "Runs a child and confirms process-owned memory is reclaimed."],
  ["XMS", "scripts/test_xms.py", "Exercises INT 2Fh discovery, single-handle allocation, moves, bounds, and free."],
  ["EMS", "scripts/test_ems.py", "Builds with ENABLE_EMS=1 and tests frame/page mapping."],
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
