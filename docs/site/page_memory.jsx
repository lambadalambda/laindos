const MEM_FLOW = [
  ["Layout", "The kernel relocates to the HMA at FFFF:0010, keeps scratch buffers below 0640h, and reserves A000h for VGA."],
  ["Arena", "One free MCB starts at 0640h and grows upward until MEM_TOP, with owner 0 meaning free."],
  ["Allocate", "INT 21h AH=48h supports first, best, and last-fit strategy, plus a high-biased small allocation path."],
  ["Own", "Program and environment blocks are stamped with the current PSP so exit cleanup can reclaim them."],
  ["Extend", "XMS is a single-handle BIOS-move shim; EMS is optional and disabled in normal builds."]];

const MEM_REGIONS = [
  ["0000:0000", "IVT and BIOS data remain in low memory because hardware and BIOS calls still own them."],
  ["0060:0000", "FAT_SEG scratch space holds the resident FAT image and is reused by FAT12/FAT16 logic."],
  ["0180:0000", "CD_BUF is the 2 KiB ISO9660 sector buffer for the CD-ROM driver."],
  ["0200:0000", "SEC_BUF and READ_CACHE_BUF are fixed one-sector buffers used by loader and filesystem paths."],
  ["0240:0000", "ROOT_SEG holds the resident root directory image, directly below the DOS arena."],
  ["0640:0000", "MCB_START begins the DOS arena for programs, PSPs, environments, and normal allocations."],
  ["9000:0000", "Optional EMS frame default; enabled only with ENABLE_EMS=1 and guarded against ROM/VGA overlap."],
  ["A000:0000", "MEM_TOP and VGA graphics memory; conventional allocations must stop before this segment."],
  ["FFFF:0010", "The High Memory Area holds the kernel image and stack; the A20 line is enabled at boot and kept on."]];

const MEM_SECTIONS = [
  {
    id: "constants",
    title: "Fixed segments define the machine",
    summary: "The low-memory layout is a contract, not a suggestion.",
    body: [
      "`src/memory.inc` is the first file to read before moving buffers. These equates decide where the boot sector loads the kernel, where the kernel relocates (the High Memory Area at FFFF:0010), where CD and FAT scratch sectors live, where the DOS arena begins, and where conventional memory ends.",
      "With the kernel image and stack resident in the HMA, low memory holds only the filesystem scratch buffers: the DOS arena starts at 0640h, right above the root directory buffer, and VGA graphics memory begins at A000h. `MEM_TOP` must stay 256-byte aligned because several bounds checks compare segment values directly."],
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
      [12, "MCB_START equ 0x0640"],
      [13, "MEM_TOP equ 0xA000"],
      [14, "ENV_PARAS equ 16"],
      [15, "ENV_SIZE_BYTES equ (ENV_PARAS * 16)"],
      [16, "ENV_OWNER_TEMP equ 0xFFFF"],
      [17, "%if (MEM_TOP & 0xFF) != 0"],
      [18, "%error \"MEM_TOP must be 256-byte aligned\""],
      [20, "MCB_SIG_M equ 'M'"],
      [21, "MCB_SIG_Z equ 'Z'"]],
    hi: [4, 6, 7, 8, 9, 12, 16, 17],
    tests: ["scripts/test_boot.py", "scripts/test_highmcb.py", "scripts/test_free.py"],
  },
  {
    id: "boot",
    title: "Boot installs the initial arena",
    summary: "Relocation, stack placement, XMS sizing, and the first MCB happen before loading a child.",
    body: [
      "The kernel enables the A20 line, copies itself to the HMA at `HMA_SEG:HMA_OFF`, switches DS/ES/SS to the relocated segment, and puts the stack at `KERNEL_STACK_TOP` near the top of the HMA. Only after serial/VGA bring-up and memory reporting does it initialize optional XMS sizing and the DOS arena.",
      "The first arena is a single last-block MCB at `MCB_START`: signature `Z`, owner zero, size `MEM_TOP - MCB_START - 1` paragraphs. Every later allocation is just a split or owner change inside that chain."],
    file: "src/kernel.asm",
    code: [
      [121, "kernel_entry:"],
      [137, "    call enable_a20"],
      [145, "    mov ax, HMA_SEG"],
      [152, "    jmp HMA_SEG:.relocated"],
      [153, ".relocated:"],
      [157, "    mov ss, ax"],
      [158, "    mov sp, KERNEL_STACK_TOP"],
      [169, "    int 0x12"],
      [170, "    mov [mem_kib], ax"],
      [178, "%if ENABLE_XMS"],
      [179, "    call init_xms_size"],
      [193, "    mov ax, MCB_START"],
      [156, "    mov es, ax"],
      [195, "    mov byte [es:0], MCB_SIG_Z"],
      [196, "    mov word [es:1], 0"],
      [197, "    mov ax, MEM_TOP - MCB_START - 1"],
      [198, "    mov word [es:3], ax"],
      [199, "    mov word [mcb_first], MCB_START"],
      [200, "    mov word [cur_psp], 0"]],
    hi: [111, 124, 145, 159, 161, 164, 165],
    tests: ["scripts/test_boot.py", "scripts/test_memfail.py", "scripts/test_highmcb.py"],
  },
  {
    id: "guards",
    title: "Compile-time guards catch overlap",
    summary: "Kernel size and buffer placement are checked before an image can boot.",
    body: [
      "The dangerous edits are not in allocation code; they are usually new kernel code, larger buffers, or an EMS frame moved into the wrong segment. The final assertions in `src/kernel.asm` stop those mistakes at NASM time.",
      "These guards keep the HMA-resident kernel clear of its own stack, keep the image small enough for the boot loader's staging area at `LOAD_SEG`, keep the low FAT/CD/sector/read/root buffers ordered, and ensure the root buffer stays below `MCB_START`."],
    file: "src/kernel.asm",
    code: [
      [3801, "%if (HMA_OFF + (kernel_end - kernel_entry)) > (KERNEL_STACK_TOP - KERNEL_STACK_GUARD_BYTES)"],
      [3802, "%error \"kernel leaves too little HMA stack guard\""],
      [3804, "%if (kernel_end - kernel_entry) > ((MEM_TOP - LOAD_SEG) * 16)"],
      [3805, "%error \"kernel exceeds boot load area\""],
      [3807, "%if (FAT_SEG + 0x120) > CD_BUF"],
      [3808, "%error \"FAT buffer overlaps CD_BUF\""],
      [3810, "%if (CD_BUF + CD_BUF_PARAS) > SEC_BUF"],
      [3811, "%error \"CD_BUF overlaps SEC_BUF\""],
      [3813, "%if (SEC_BUF + SECTOR_BUF_PARAS) > READ_CACHE_BUF"],
      [3814, "%error \"SEC_BUF overlaps READ_CACHE_BUF\""],
      [3816, "%if (READ_CACHE_BUF + SECTOR_BUF_PARAS) > ROOT_SEG"],
      [3817, "%error \"READ_CACHE_BUF overlaps ROOT_SEG\""],
      [3819, "%if (ROOT_SEG + ROOT_BUF_PARAS) > MCB_START"],
      [3820, "%error \"ROOT_SEG overlaps MCB arena\""],
      [3822, "%if MCB_START >= MEM_TOP"],
      [3823, "%error \"MCB arena is empty\""],
      [3825, "%if ENABLE_EMS && EMS_FRAME_SEG <= MCB_START"],
      [3826, "%error \"EMS frame must be inside conventional arena\""],
      [3837, "%if ENABLE_XMS && XMS_MAX_KB > 15360"],
      [{a: "xms_backing_limit_error"}, "%error \"XMS BIOS move backing must remain below 16 MiB\""]],
    hi: [3317, 3320, 3323, 3326, 3332, 3335, 3341, 3353],
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
      [18, "%macro MCB_WALK_EACH 6"],
      [21, "    MCB_IS_VALID"],
      [25, "    cmp byte [ds:0], MCB_SIG_Z"],
      [27, "    call mcb_walk_next"],
      [32, "alloc_mem_direct:"],
      [36, "    mov si, [cs:mcb_first]"],
      [37, "    MCB_WALK_EACH .amd_walk, .amd_check, .amd_next, .amd_nomem, .amd_nomem, .amd_nomem"],
      [39, "    cmp word [ds:1], 0"],
      [42, "    cmp ax, [cs:am_req]"],
      [46, "    cmp ax, 2"],
      [55, "    mov byte [es:0], al"],
      [56, "    mov word [es:1], 0"],
      [60, "    mov word [es:3], cx"],
      [61, "    mov byte [ds:0], MCB_SIG_M"],
      [63, "    mov word [ds:3], ax"],
      [67, "    mov ax, [cs:cur_psp]"],
      [68, "    mov word [ds:1], ax"],
      [70, "    inc ax"]],
    hi: [1, 18, 32, 37, 46, 61, 68, 70],
    tests: ["scripts/test_highmcb.py", "scripts/test_envmcb.py", "scripts/test_memrelease.py"],
  },
  {
    id: "strategy",
    title: "DOS allocation strategy is visible",
    summary: "AH=58h selects first, best, or last fit; AH=48h applies it.",
    body: [
      "Programs can query and set the DOS allocation strategy through `INT 21h AH=58h`. LainDOS stores only values 0 through 2, matching first-fit, best-fit, and last-fit behavior used by the allocator.",
      "The default first-fit path has one compatibility twist: requests from 2 through `SMALL_ALLOC_HIGH_MAX` paragraphs are biased to the last suitable block. That keeps tiny runtime allocations from fragmenting the low end of the arena before larger program loads."],
    file: "src/kernel/int21.inc",
    code: [
      [1426, ".alloc_strategy:"],
      [1162, "    cmp al, 0"],
      [1440, "    je .as_get"],
      [1172, "    cmp al, 1"],
      [1442, "    je .as_set"],
      [780, "    xor ax, ax"],
      [1571, "    mov al, [cs:alloc_strat]"],
      [1449, "    cmp bl, 2"],
      [1451, "    mov [cs:alloc_strat], bl"],
      [1488, ".alloc_mem:"],
      [1571, "    mov al, [cs:alloc_strat]"],
      [1174, "    cmp al, 2"],
      [1511, "    jmp near .am_find_last"],
      [1503, "    cmp al, 1"],
      [1505, "    jmp near .am_find_best"],
      [1507, "    cmp word [cs:am_req], 1"],
      [1509, "    cmp word [cs:am_req], SMALL_ALLOC_HIGH_MAX"],
      [1511, "    jmp near .am_find_last"],
      [1621, "    mov si, [cs:mcb_first]"],
      [1634, "    cmp ax, [cs:am_req]"],
      [1528, ".am_use:"],
      [1149, "    mov ax, [cs:cur_psp]"],
      [1594, ".am_find_last:"],
      [1618, ".am_find_best:"],
      [1675, ".am_nomem:"],
      [1678, ".am_scan_largest:"],
      [1915, "    mov ax, 8"]],
    hi: [1224, 1259, 1298, 1319, 1404, 1428, 1488],
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
      [1725, ".free_mem:"],
      [1757, "    mov si, es"],
      [1758, "    dec si"],
      [1624, "    cmp byte [ds:0], MCB_SIG_M"],
      [1641, "    cmp byte [ds:0], MCB_SIG_Z"],
      [1741, "    mov word [ds:1], 0"],
      [1742, "    call mcb_merge_free_forward"],
      [1749, ".resize_mem:"],
      [1756, "    mov [cs:rm_req], bx"],
      [1757, "    mov si, es"],
      [1633, "    mov ax, [ds:3]"],
      [1769, "    jae .rm_shrink"],
      [1777, "    cmp byte [es:0], MCB_SIG_M"],
      [1782, "    cmp word [es:1], 0"],
      [1869, "    add ax, cx"],
      [1787, "    cmp ax, bx"],
      [1822, "    mov byte [es:0], dl"],
      [1665, "    mov byte [ds:0], MCB_SIG_M"],
      [1545, "    mov word [es:3], cx"],
      [1827, "    mov word [ds:3], bx"],
      [1812, "    mov ax, [ds:3]"],
      [1822, "    mov byte [es:0], dl"],
      [1541, "    mov word [es:1], 0"],
      [1827, "    mov word [ds:3], bx"],
      [1870, "    mov [es:0x02], ax"],
      [1913, ".rm_cant_grow:"],
      [1914, "    mov bx, ax"],
      [1915, "    mov ax, 8"]],
    hi: [1535, 1551, 1552, 1559, 1592, 1633, 1680, 1723],
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
      [666, "    mov word [cs:exec_env_seg], 0"],
      [490, "    mov bx, ENV_PARAS"],
      [672, "    call alloc_mem_direct"],
      [674, "    mov [cs:exec_env_seg], ax"],
      [677, "    dec ax"],
      [678, "    mov ds, ax"],
      [{a: "alloc_exec_environment_temp_owner"}, "    mov word [ds:1], ENV_OWNER_TEMP"],
      [{a: "free_exec_environment_start"}, "free_exec_environment:"],
      [677, "    dec ax"],
      [{a: "free_exec_environment_coalesce"}, "    mov word [ds:1], 0"],
      [720, "assign_exec_environment_owner:"],
      [724, "    mov bx, [cs:exec_env_seg]"],
      [729, "    dec bx"],
      [734, "    mov ax, [cs:cur_psp]"],
      [{a: "env_owner_store"}, "    mov [ds:1], ax"]],
    hi: [{a: "alloc_exec_environment_start"}, {a: "alloc_exec_environment_temp_owner"}, {a: "free_exec_environment_start"}, 508, 522, 523],
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
      [2485, "do_terminate:"],
      [2495, "%if ENABLE_EMS"],
      [2352, "    mov word [cs:ems_alloc_pages], 0"],
      [2499, "    mov word [cs:xms_alloc_kb], 0"],
      [2500, "    call release_inherited_handles"],
      [2501, "    call close_owned_handles"],
      [2503, "    mov si, [cs:mcb_first]"],
      [2505, "    mov ds, si"],
      [2512, "    mov ax, [cs:cur_psp]"],
      [2513, "    cmp word [ds:1], ax"],
      [2515, "    mov word [ds:1], 0"],
      [2519, "    call mcb_walk_next"],
      [2523, "    call mcb_coalesce_all_free"],
      [2528, "    mov ax, [0x16]"],
      [{a: "do_terminate_restore_parent_psp"}, "    mov [cs:cur_psp], ax"]],
    hi: [2144, 2157, 2161, 2171, 2173, 2181, 2187],
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
      [43, "%ifndef XMS_MAX_KB"],
      [44, "%define XMS_MAX_KB 15360"],
      [113, "%ifndef ENABLE_XMS"],
      [114, "%define ENABLE_XMS 1"],
      [1831, "init_xms_size:"],
      [1833, "    mov word [cs:xms_total_kb], 0"],
      [1834, "    mov ah, 0x88"],
      [1835, "    int 0x15"],
      [1840, "    cmp ax, XMS_MAX_KB - 64"],
      [1842, "    mov ax, XMS_MAX_KB - 64"],
      [1844, "    mov [cs:xms_total_kb], ax"],
      [1866, "int2f_handler:"],
      [1876, "    cmp ax, 0x4300"],
      [1878, "    cmp ax, 0x4310"],
      [1884, "    mov al, 0x80"],
      [1887, "    mov bx, xms_entry"],
      [1900, "xms_entry:"],
      [1917, "    cmp ah, 0x08"],
      [1919, "    cmp ah, 0x09"],
      [1921, "    cmp ah, 0x0A"],
      [1923, "    cmp ah, 0x0B"],
      [1960, "    mov ax, [cs:xms_total_kb]"],
      [1984, "    cmp word [cs:xms_alloc_kb], 0"],
      [1970, "    cmp dx, [cs:xms_total_kb]"],
      [1972, "    mov [cs:xms_alloc_kb], dx"],
      [1987, "    mov ax, 1"],
      [1974, "    mov dx, 1"],
      [1986, "    mov word [cs:xms_alloc_kb], 0"],
      [1990, ".move:"],
      [1999, "    test ax, 1"],
      [2007, "    call xms_prepare_endpoint"],
      [2007, "    call xms_prepare_endpoint"],
      [2061, "    mov ax, 0x8700"],
      [{a: "xms_move_bios_call"}, "    int 0x15"]],
    hi: [43, 88, 1583, 1610, 1613, 1623, 1661, 1679, 1755],
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
      [46, "EMS_TOTAL_PAGES equ 64"],
      [47, "%ifndef EMS_FRAME_SEG"],
      [48, "%define EMS_FRAME_SEG 0x9000"],
      [50, "EMS_FRAME_PARAS equ 0x1000"],
      [53, "EMS_BACKING_HI equ 0x0020"],
      [117, "%ifndef ENABLE_EMS"],
      [118, "%define ENABLE_EMS 0"],
      [1631, "%if ENABLE_EMS"],
      [1632, "    mov [es:0x67*4], word int67_handler"],
      [1634, "%else"],
      [1635, "    mov [es:0x67*4], word int67_absent_handler"],
      [2218, "%if !ENABLE_EMS"],
      [2219, "int67_absent_handler:"],
      [2220, "    mov ah, 0x80"],
      [2224, "%if ENABLE_EMS"],
      [2225, "int67_handler:"],
      [2249, ".frame:"],
      [2251, "    mov bx, EMS_FRAME_SEG"],
      [2253, ".pages:"],
      [2254, "    mov bx, EMS_TOTAL_PAGES"],
      [2259, ".alloc:"],
      [2264, "    cmp bx, EMS_TOTAL_PAGES"],
      [2266, "    mov [cs:ems_alloc_pages], bx"],
      [2274, ".map:"],
      [2279, "    cmp al, 3"],
      [2281, "    cmp bx, [cs:ems_alloc_pages]"],
      [2306, "    call ems_copy_16k"],
      [2306, "    call ems_copy_16k"],
      [2324, "    mov [cs:si+ems_map_pages], bx"],
      [2352, "    mov word [cs:ems_alloc_pages], 0"],
      [2376, "ems_clear_map:"],
      [{a: "ems_clear_map_fill"}, "    mov word [cs:ems_map_pages], 0xFFFF"]],
    hi: [92, 1453, 1907, 1913, 1939, 1954, 1962, 1994, 2012],
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
    hi: [13, 22, 27, 35, 52, 55, 70, 93],
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
              <window.MemoryMap touches={["ivt", "bda", "fat", "kernel", "sec", "cache", "root", "arena", "vga"]} compact={true} />
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
