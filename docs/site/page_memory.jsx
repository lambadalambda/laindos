const MEM_FLOW = [
  ["Layout", "The kernel relocates to 0340h, keeps scratch buffers below 1000h, and reserves A000h for VGA."],
  ["Arena", "One free MCB starts at 1000h and grows upward until MEM_TOP, with owner 0 meaning free."],
  ["Allocate", "INT 21h AH=48h supports first, best, and last-fit strategy, plus a high-biased small allocation path."],
  ["Own", "Program and environment blocks are stamped with the current PSP so exit cleanup can reclaim them."],
  ["Extend", "XMS is a single-handle BIOS-move shim; EMS is optional and disabled in normal builds."]];

const MEM_REGIONS = [
  ["0000:0000", "IVT and BIOS data remain in low memory because hardware and BIOS calls still own them."],
  ["0060:0000", "FAT_SEG scratch space is below the relocated kernel and reused by FAT12/FAT16 logic."],
  ["0340:0000", "The relocated kernel and stack live here; compile-time guards keep them below buffers and MCB_START."],
  ["0B00:0000", "SEC_BUF and READ_CACHE_BUF are fixed one-sector buffers used by loader and filesystem paths."],
  ["0B40:0000", "ROOT_SEG holds the resident root directory image and must not collide with the kernel stack."],
  ["1000:0000", "MCB_START begins the DOS arena for programs, PSPs, environments, and normal allocations."],
  ["9000:0000", "Optional EMS frame default; enabled only with ENABLE_EMS=1 and guarded against ROM/VGA overlap."],
  ["A000:0000", "MEM_TOP and VGA graphics memory; conventional allocations must stop before this segment."]];

const MEM_SECTIONS = [
  {
    id: "constants",
    title: "Fixed segments define the machine",
    summary: "The low-memory layout is a contract, not a suggestion.",
    body: [
      "`src/memory.inc` is the first file to read before moving buffers. These equates decide where the kernel relocates, where scratch sectors live, where the DOS arena begins, and where conventional memory ends.",
      "The split is intentionally conservative: filesystem scratch buffers sit below the MCB arena, programs start at 1000h, and VGA graphics memory begins at A000h. `MEM_TOP` must stay 256-byte aligned because several bounds checks compare segment values directly."],
    file: "src/memory.inc",
    code: [
      [3, "LOAD_SEG equ 0x1000"],
      [4, "RELOC_SEG equ 0x0340"],
      [5, "SECTOR_BUF_PARAS equ 0x20"],
      [6, "SEC_BUF equ 0x0B00"],
      [7, "READ_CACHE_BUF equ (SEC_BUF + SECTOR_BUF_PARAS)"],
      [8, "MCB_START equ 0x1000"],
      [9, "MEM_TOP equ 0xA000"],
      [10, "ENV_PARAS equ 16"],
      [11, "ENV_SIZE_BYTES equ (ENV_PARAS * 16)"],
      [12, "ENV_OWNER_TEMP equ 0xFFFF"],
      [13, "%if (MEM_TOP & 0xFF) != 0"],
      [14, "%error \"MEM_TOP must be 256-byte aligned\""],
      [16, "MCB_SIG_M equ 'M'"],
      [17, "MCB_SIG_Z equ 'Z'"]],
    hi: [4, 6, 7, 8, 9, 12, 16, 17],
    tests: ["scripts/test_boot.py", "scripts/test_highmcb.py", "scripts/test_free.py"],
  },
  {
    id: "boot",
    title: "Boot installs the initial arena",
    summary: "Relocation, stack placement, XMS sizing, and the first MCB happen before loading a child.",
    body: [
      "The kernel copies itself to `RELOC_SEG`, switches DS/ES/SS to the relocated segment, and puts the stack at `KERNEL_STACK_TOP`. Only after serial/VGA bring-up and memory reporting does it initialize optional XMS sizing and the DOS arena.",
      "The first arena is a single last-block MCB at `MCB_START`: signature `Z`, owner zero, size `MEM_TOP - MCB_START - 1` paragraphs. Every later allocation is just a split or owner change inside that chain."],
    file: "src/kernel.asm",
    code: [
      [95, "kernel_entry:"],
      [111, "    mov ax, RELOC_SEG"],
      [118, "    jmp RELOC_SEG:.relocated"],
      [119, ".relocated:"],
      [123, "    mov ss, ax"],
      [124, "    mov sp, KERNEL_STACK_TOP"],
      [135, "    int 0x12"],
      [136, "    mov [mem_kib], ax"],
      [144, "%if ENABLE_XMS"],
      [145, "    call init_xms_size"],
      [159, "    mov ax, MCB_START"],
      [160, "    mov es, ax"],
      [161, "    mov byte [es:0], MCB_SIG_Z"],
      [162, "    mov word [es:1], 0"],
      [163, "    mov ax, MEM_TOP - MCB_START - 1"],
      [164, "    mov word [es:3], ax"],
      [165, "    mov word [mcb_first], MCB_START"],
      [166, "    mov word [cur_psp], 0"]],
    hi: [111, 124, 145, 159, 161, 164, 165],
    tests: ["scripts/test_boot.py", "scripts/test_memfail.py", "scripts/test_highmcb.py"],
  },
  {
    id: "guards",
    title: "Compile-time guards catch overlap",
    summary: "Kernel size and buffer placement are checked before an image can boot.",
    body: [
      "The dangerous edits are not in allocation code; they are usually new kernel code, larger buffers, or an EMS frame moved into the wrong segment. The final assertions in `src/kernel.asm` stop those mistakes at NASM time.",
      "These guards keep the loaded kernel below the loader gap, prevent it from reaching `SEC_BUF`, keep sector/read/root buffers ordered, preserve a root-stack guard, and ensure the stack plus buffers stay below `MCB_START`."],
    file: "src/kernel.asm",
    code: [
      [3311, "%if LOAD_SEG <= RELOC_SEG"],
      [3312, "%error \"LOAD_SEG must be above RELOC_SEG\""],
      [3314, "%if (kernel_end - kernel_entry) > ((LOAD_SEG - RELOC_SEG) * 16)"],
      [3315, "%error \"kernel exceeds boot relocation gap\""],
      [3317, "%if (kernel_end - kernel_entry) > ((SEC_BUF - RELOC_SEG) * 16)"],
      [3318, "%error \"kernel overlaps SEC_BUF\""],
      [3320, "%if (SEC_BUF + SECTOR_BUF_PARAS) > READ_CACHE_BUF"],
      [3321, "%error \"SEC_BUF overlaps READ_CACHE_BUF\""],
      [3323, "%if (READ_CACHE_BUF + SECTOR_BUF_PARAS) > ROOT_SEG"],
      [3324, "%error \"READ_CACHE_BUF overlaps ROOT_SEG\""],
      [3326, "%if (ROOT_SEG + ROOT_BUF_PARAS) > (RELOC_SEG + (KERNEL_STACK_TOP / 16))"],
      [3327, "%error \"ROOT buffer overlaps kernel stack\""],
      [3329, "%if (ROOT_SEG + ROOT_BUF_PARAS + STACK_ROOT_GUARD_PARAS) > (RELOC_SEG + (KERNEL_STACK_TOP / 16))"],
      [3330, "%error \"ROOT buffer leaves too little kernel stack guard\""],
      [3332, "%if (RELOC_SEG + (KERNEL_STACK_TOP / 16)) > MCB_START"],
      [3333, "%error \"kernel stack overlaps MCB arena\""],
      [3335, "%if (ROOT_SEG + ROOT_BUF_PARAS) > MCB_START"],
      [3336, "%error \"ROOT_SEG overlaps MCB arena\""],
      [3338, "%if ENABLE_EMS && EMS_FRAME_SEG <= MCB_START"],
      [3339, "%error \"EMS frame must be inside conventional arena\""],
      [3350, "%if ENABLE_XMS && XMS_MAX_KB > 15360"],
      [3351, "%error \"XMS BIOS move backing must remain below 16 MiB\""]],
    hi: [3314, 3317, 3320, 3323, 3329, 3332, 3338, 3350],
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
      [18, "alloc_mem_direct:"],
      [22, "    mov si, [cs:mcb_first]"],
      [25, "    cmp byte [ds:0], MCB_SIG_M"],
      [27, "    cmp byte [ds:0], MCB_SIG_Z"],
      [34, "    cmp word [ds:1], 0"],
      [37, "    cmp ax, [cs:am_req]"],
      [41, "    cmp ax, 2"],
      [50, "    mov byte [es:0], al"],
      [51, "    mov word [es:1], 0"],
      [55, "    mov word [es:3], cx"],
      [56, "    mov byte [ds:0], MCB_SIG_M"],
      [58, "    mov word [ds:3], ax"],
      [62, "    mov ax, [cs:cur_psp]"],
      [63, "    mov word [ds:1], ax"],
      [65, "    inc ax"]],
    hi: [1, 18, 41, 56, 63, 65],
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
      [1216, ".alloc_strategy:"],
      [1239, "    cmp al, 0"],
      [1240, "    je .as_get"],
      [1241, "    cmp al, 1"],
      [1242, "    je .as_set"],
      [1245, "    xor ax, ax"],
      [1246, "    mov al, [cs:alloc_strat]"],
      [1249, "    cmp bl, 2"],
      [1251, "    mov [cs:alloc_strat], bl"],
      [1290, ".alloc_mem:"],
      [1299, "    mov al, [cs:alloc_strat]"],
      [1301, "    cmp al, 2"],
      [1303, "    jmp near .am_find_last"],
      [1305, "    cmp al, 1"],
      [1307, "    jmp near .am_find_best"],
      [1309, "    cmp word [cs:am_req], 1"],
      [1311, "    cmp word [cs:am_req], SMALL_ALLOC_HIGH_MAX"],
      [1313, "    jmp near .am_find_last"],
      [1315, "    mov si, [cs:mcb_first]"],
      [1328, "    cmp ax, [cs:am_req]"],
      [1330, ".am_use:"],
      [1354, "    mov ax, [cs:cur_psp]"],
      [1396, ".am_find_last:"],
      [1420, ".am_find_best:"],
      [1477, ".am_nomem:"],
      [1480, ".am_scan_largest:"],
      [1501, "    mov ax, 8"]],
    hi: [1216, 1251, 1290, 1311, 1396, 1420, 1480],
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
      [1527, ".free_mem:"],
      [1533, "    mov si, es"],
      [1534, "    dec si"],
      [1536, "    cmp byte [ds:0], MCB_SIG_M"],
      [1538, "    cmp byte [ds:0], MCB_SIG_Z"],
      [1543, "    mov word [ds:1], 0"],
      [1544, "    call mcb_merge_free_forward"],
      [1551, ".resize_mem:"],
      [1558, "    mov [cs:rm_req], bx"],
      [1559, "    mov si, es"],
      [1569, "    mov ax, [ds:3]"],
      [1571, "    jae .rm_shrink"],
      [1579, "    cmp byte [es:0], MCB_SIG_M"],
      [1584, "    cmp word [es:1], 0"],
      [1588, "    add ax, cx"],
      [1589, "    cmp ax, bx"],
      [1603, "    mov byte [es:0], dl"],
      [1604, "    mov byte [ds:0], MCB_SIG_M"],
      [1609, "    mov word [es:3], cx"],
      [1610, "    mov word [ds:3], bx"],
      [1614, "    mov ax, [ds:3]"],
      [1624, "    mov byte [es:0], dl"],
      [1625, "    mov word [es:1], 0"],
      [1629, "    mov word [ds:3], bx"],
      [1672, "    mov [es:0x02], ax"],
      [1715, ".rm_cant_grow:"],
      [1716, "    mov bx, ax"],
      [1717, "    mov ax, 8"]],
    hi: [1527, 1543, 1544, 1551, 1584, 1625, 1672, 1715],
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
      [423, "    mov word [cs:exec_env_seg], 0"],
      [425, "    mov bx, ENV_PARAS"],
      [426, "    call alloc_mem_direct"],
      [428, "    mov [cs:exec_env_seg], ax"],
      [431, "    dec ax"],
      [432, "    mov ds, ax"],
      [{a: "alloc_exec_environment_temp_owner"}, "    mov word [ds:1], ENV_OWNER_TEMP"],
      [{a: "free_exec_environment_start"}, "free_exec_environment:"],
      [456, "    dec ax"],
      [{a: "free_exec_environment_coalesce"}, "    mov word [ds:1], 0"],
      [476, "assign_exec_environment_owner:"],
      [480, "    mov bx, [cs:exec_env_seg]"],
      [485, "    dec bx"],
      [492, "    mov ax, [cs:cur_psp]"],
      [493, "    mov [ds:1], ax"]],
    hi: [{a: "alloc_exec_environment_start"}, {a: "alloc_exec_environment_temp_owner"}, {a: "free_exec_environment_start"}, 476, 492, 493],
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
      [2144, "do_terminate:"],
      [2153, "%if ENABLE_EMS"],
      [2154, "    mov word [cs:ems_alloc_pages], 0"],
      [2157, "    mov word [cs:xms_alloc_kb], 0"],
      [2158, "    call release_inherited_handles"],
      [2159, "    call close_owned_handles"],
      [2161, "    mov si, [cs:mcb_first]"],
      [2163, "    mov ds, si"],
      [2170, "    mov ax, [cs:cur_psp]"],
      [2171, "    cmp word [ds:1], ax"],
      [2173, "    mov word [ds:1], 0"],
      [2177, "    call mcb_walk_next"],
      [2181, "    call mcb_coalesce_all_free"],
      [2186, "    mov ax, [0x16]"],
      [2187, "    mov [cs:cur_psp], ax"]],
    hi: [2144, 2157, 2161, 2171, 2173, 2181, 2187],
    tests: ["scripts/test_memrelease.py", "scripts/test_free.py", "scripts/test_shell.py"],
  },
  {
    id: "xms",
    title: "XMS is a single-handle shim",
    summary: "INT 2Fh advertises an XMS entry point backed by BIOS INT 15h moves.",
    body: [
      "On boot, LainDOS asks BIOS `INT 15h AH=88h` for extended memory and caps it at `XMS_MAX_KB`. `INT 2Fh AX=4300h/4310h` then advertises one XMS entry point for callers that probe HIMEM-style services.",
      "The implementation intentionally supports a single allocated handle: allocation succeeds only if no handle is active, handle 1 represents the whole block, and moves validate both real-mode endpoints and XMS offsets before chunking through BIOS `INT 15h AH=87h`."],
    file: "src/kernel.asm",
    code: [
      [42, "%ifndef XMS_MAX_KB"],
      [43, "%define XMS_MAX_KB 15360"],
      [87, "%ifndef ENABLE_XMS"],
      [88, "%define ENABLE_XMS 1"],
      [1583, "init_xms_size:"],
      [1585, "    mov word [cs:xms_total_kb], 0"],
      [1586, "    mov ah, 0x88"],
      [1587, "    int 0x15"],
      [1591, "    cmp ax, XMS_MAX_KB"],
      [1593, "    mov ax, XMS_MAX_KB"],
      [1595, "    mov [cs:xms_total_kb], ax"],
      [1601, "int2f_handler:"],
      [1603, "    cmp ax, 0x4300"],
      [1605, "    cmp ax, 0x4310"],
      [1610, "    mov al, 0x80"],
      [1613, "    mov bx, xms_entry"],
      [1623, "xms_entry:"],
      [1626, "    cmp ah, 0x08"],
      [1628, "    cmp ah, 0x09"],
      [1630, "    cmp ah, 0x0A"],
      [1632, "    cmp ah, 0x0B"],
      [1649, "    mov ax, [cs:xms_total_kb]"],
      [1655, "    cmp word [cs:xms_alloc_kb], 0"],
      [1659, "    cmp dx, [cs:xms_total_kb]"],
      [1661, "    mov [cs:xms_alloc_kb], dx"],
      [1662, "    mov ax, 1"],
      [1663, "    mov dx, 1"],
      [1675, "    mov word [cs:xms_alloc_kb], 0"],
      [1679, ".move:"],
      [1688, "    test ax, 1"],
      [1696, "    call xms_prepare_endpoint"],
      [1704, "    call xms_prepare_endpoint"],
      [1750, "    mov ax, 0x8700"],
      [1755, "    int 0x15"]],
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
      [45, "EMS_TOTAL_PAGES equ 64"],
      [46, "%ifndef EMS_FRAME_SEG"],
      [47, "%define EMS_FRAME_SEG 0x9000"],
      [49, "EMS_FRAME_PARAS equ 0x1000"],
      [52, "EMS_BACKING_HI equ 0x0020"],
      [91, "%ifndef ENABLE_EMS"],
      [92, "%define ENABLE_EMS 0"],
      [1449, "%if ENABLE_EMS"],
      [1450, "    mov [es:0x67*4], word int67_handler"],
      [1452, "%else"],
      [1453, "    mov [es:0x67*4], word int67_absent_handler"],
      [1906, "%if !ENABLE_EMS"],
      [1907, "int67_absent_handler:"],
      [1908, "    mov ah, 0x80"],
      [1912, "%if ENABLE_EMS"],
      [1913, "int67_handler:"],
      [1937, ".frame:"],
      [1939, "    mov bx, EMS_FRAME_SEG"],
      [1941, ".pages:"],
      [1942, "    mov bx, EMS_TOTAL_PAGES"],
      [1947, ".alloc:"],
      [1952, "    cmp bx, EMS_TOTAL_PAGES"],
      [1954, "    mov [cs:ems_alloc_pages], bx"],
      [1962, ".map:"],
      [1967, "    cmp al, 3"],
      [1969, "    cmp bx, [cs:ems_alloc_pages]"],
      [1994, "    call ems_copy_16k"],
      [2005, "    call ems_copy_16k"],
      [2012, "    mov [cs:si+ems_map_pages], bx"],
      [2040, "    mov word [cs:ems_alloc_pages], 0"],
      [2064, "ems_clear_map:"],
      [2065, "    mov word [cs:ems_map_pages], 0xFFFF"]],
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
      [70, "query_xms:"],
      [75, "    mov ax, 0x4300"],
      [76, "    int 0x2F"],
      [86, "    mov ah, 0x08"],
      [87, "    call far [xms_entry]"],
      [93, "query_ems:"],
      [97, "    mov ah, 0x40"],
      [98, "    int 0x67"],
      [101, "    mov ah, 0x42"],
      [102, "    int 0x67"]],
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
