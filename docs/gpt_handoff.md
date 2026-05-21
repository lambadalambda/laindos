A practical plan for a **tiny DOS whose first serious target is starting The Secret of Monkey Island**, not becoming a general FreeDOS replacement.

The key idea: **do not implement “DOS” in the abstract. Implement the subset needed to boot, load `MONKEY.EXE`, serve its file/memory/version/vector calls, and leave BIOS/VGA/timer/keyboard hardware alone.**

## 0. Define the first success target

Target this first:

> Boot a disk image in QEMU, mount `C:\MONKEY`, auto-run `MONKEY.EXE`, reach the Monkey Island intro/copy-protection/title screen, with keyboard working, no sound, and mouse optional.

The DOSDays writeup says Monkey Island 1 can run on an XT-compatible machine, is not especially memory-intensive, and the VGA version uses 320×200 with 256 colors; it also notes that mouse is strongly preferable but not conceptually required for the game to start. ([dosdays.co.uk][1])

So the first version should **not** try to support:

* DPMI, VCPI, EMS, XMS.
* Hard disk partitioning beyond one simple FAT volume.
* DOS device drivers.
* `CONFIG.SYS`.
* Full `COMMAND.COM`.
* Sound Blaster, AdLib, MT-32.
* Printing, networking, SHARE, redirectors.
* Full MS-DOS 4 behavior.

Use QEMU as the default emulator. Use **Bochs** when you need its debugger for tricky real-mode issues, because it emulates the x86 CPU, common I/O devices, and BIOS, and can run DOS-like operating systems inside the emulator. ([bochs.sourceforge.io][2])

## 1. Toolchain choice

Use a split toolchain:

**Assembly:** NASM for boot sector, interrupt trampolines, real-mode entry code, and far-call glue. NASM’s project page describes it as an x86 assembler with code generation for old and new platforms. ([nasm.us][3])

**C compiler:** Open Watcom or GCC IA-16. I would start with **Open Watcom**, because its docs explicitly cover 16-bit DOS targets, and the Open Watcom v2 linker guide shows `system dos` for 16-bit DOS `.EXE` files and `system com` for 16-bit `.COM` files. ([open-watcom.github.io][4]) ([open-watcom.github.io][5])

**Reference material:** Use Ralf Brown’s Interrupt List and the MS-DOS 4.00 source as references, but be careful with license contamination if you look at FreeDOS code. Microsoft says MS-DOS 4.00 was released under MIT; FreeDOS kernel source is GPL and implements core MS/PC-DOS-compatible functions, so copying FreeDOS code would pull you toward GPL. ([opensource.microsoft.com][6]) ([GitHub][7])

## 2. Architecture: “single-task DOS personality”

Use this memory layout initially:

```text
0000:0000  Interrupt Vector Table
0040:0000  BIOS Data Area
0050:0000  scratch / low DOS data
0070:0000  bootloader transient area
0800:0000  tiny DOS kernel, disk buffers, handle tables
1000:0000  start of allocatable DOS memory
A000:0000  VGA graphics memory
```

At boot, ask BIOS for conventional memory size via `INT 12h`, then create one DOS memory arena from “end of kernel” up to the reported conventional-memory top, excluding video memory. Do not try to be clever with UMBs, HMA, XMS, EMS, or load-high behavior.

The kernel should be a single real-mode, non-reentrant, single-tasking kernel. That is authentic enough for early DOS games.

## 3. Disk and filesystem strategy

Do not write a full disk stack first. Let BIOS do the block I/O.

Use:

```text
BIOS INT 13h  -> read/write sectors
your FAT code -> FAT12 or FAT16 filesystem
your DOS API  -> open/read/write/seek/find
```

For the first build, make a simple bootable FAT12 or FAT16 image with:

```text
C:\
  KERNEL.SYS
  AUTOEXEC.BAT        optional, can be fake
  MONKEY\
    MONKEY.EXE
    *.LEC / *.LFL / game data files
```

Better yet, initially skip `AUTOEXEC.BAT` and have your kernel directly execute:

```text
C:\MONKEY\MONKEY.EXE
```

Implement FAT in this order:

1. Read boot sector / BPB.
2. Locate FAT, root directory, and data region.
3. Read root directory.
4. Read subdirectories.
5. Open/read/seek/close files.
6. Add create/write only when saves are needed.

For **starting** Monkey Island, read-only file support may get you quite far. For actual play, you will eventually need writes for saves.

## 4. Boot path milestones

### Milestone A: boot and print

Write a 512-byte boot sector that loads `KERNEL.SYS` from the root directory.

Success test:

```text
Boots in QEMU.
Prints "MiniDOS booted".
Can read sectors using BIOS.
```

At this stage, use BIOS `INT 10h` teletype output for debugging.

### Milestone B: load kernel from FAT

Boot sector should find `KERNEL.SYS` by name, follow its cluster chain, and load it into memory.

Success test:

```text
Boot sector loads 20–60 KiB kernel.
Kernel prints FAT geometry and memory size.
```

### Milestone C: install DOS interrupt handlers

Install at least:

```text
INT 20h  terminate program
INT 21h  DOS API
INT 22h  terminate vector
INT 23h  Ctrl-C vector, can stub
INT 24h  critical error vector, can stub
```

Leave BIOS interrupts alone:

```text
INT 10h  video BIOS
INT 13h  disk BIOS
INT 16h  keyboard BIOS
INT 1Ah  clock BIOS
INT 08h  timer IRQ
INT 09h  keyboard IRQ
```

Games will often call BIOS or hardware directly. That is fine. You are not trying to virtualize the PC.

## 5. Implement the `.EXE` loader

Monkey Island will almost certainly be an MZ `.EXE`, not a tiny `.COM`, so the MZ loader is central.

Implement:

1. Parse MZ header.
2. Compute image size.
3. Allocate a memory block for PSP + program image + minimum extra memory.
4. Build PSP at the load segment.
5. Load executable image at `PSP + 10h`.
6. Apply relocation table by adding the load segment.
7. Set up initial `CS:IP` and `SS:SP`.
8. Set `DS = ES = PSP`.
9. Far jump to program entry.

The PSP should include at least:

```text
offset 00h: CD 20          ; INT 20h
offset 02h: end segment
offset 0Ah: INT 22h vector
offset 0Eh: INT 23h vector
offset 12h: INT 24h vector
offset 2Ch: environment segment
offset 5Ch: default FCB 1
offset 6Ch: default FCB 2
offset 80h: command tail
```

For `MONKEY.EXE`, the command tail can initially be empty.

## 6. Implement only the DOS API subset you need first

The core interrupt is `INT 21h`. Ralf Brown’s Interrupt List is a useful map because it covers real-mode BIOS interrupts, DOS interrupts, I/O ports, memory regions, CMOS, and related PC details. ([wiki.osdev.org][8])

Start with this `INT 21h` set:

| Function | Purpose                     | Priority |
| -------- | --------------------------- | -------: |
| `AH=09h` | print `$`-terminated string |     high |
| `AH=19h` | get current drive           |     high |
| `AH=1Ah` | set DTA                     |     high |
| `AH=25h` | set interrupt vector        |     high |
| `AH=2Ah` | get date                    |   medium |
| `AH=2Ch` | get time                    |   medium |
| `AH=2Fh` | get DTA                     |     high |
| `AH=30h` | get DOS version             |     high |
| `AH=35h` | get interrupt vector        |     high |
| `AH=3Ch` | create file                 |   medium |
| `AH=3Dh` | open file                   |     high |
| `AH=3Eh` | close file                  |     high |
| `AH=3Fh` | read file                   |     high |
| `AH=40h` | write file                  |   medium |
| `AH=42h` | seek file                   |     high |
| `AH=43h` | get/set file attributes     |   medium |
| `AH=44h` | IOCTL, minimal stubs        |   medium |
| `AH=47h` | get current directory       |     high |
| `AH=48h` | allocate memory             |     high |
| `AH=49h` | free memory                 |     high |
| `AH=4Ah` | resize memory block         |     high |
| `AH=4Bh` | EXEC                        |     high |
| `AH=4Ch` | terminate with return code  |     high |
| `AH=4Eh` | find first                  |     high |
| `AH=4Fh` | find next                   |     high |
| `AH=56h` | rename file                 |      low |
| `AH=57h` | get/set file date/time      |   medium |
| `AH=62h` | get PSP segment             |   medium |

Do not guess wildly. Implement a logger: whenever an unimplemented `INT 21h` function is called, print or record:

```text
INT 21h AH=xx AL=yy AX=zzzz BX=zzzz CX=zzzz DX=zzzz DS=zzzz ES=zzzz
```

Then add functions in the order Monkey Island asks for them.

## 7. Version lie: return DOS 3.30 first, not necessarily 4.00

Although you are thinking “MS-DOS 4 level,” many games of that era are happiest with DOS 3.x semantics. I would make `INT 21h AH=30h` return:

```text
AL = 3
AH = 30
```

or maybe:

```text
AL = 3
AH = 31
```

Then only switch to 4.00 if the game or installer expects it. The goal is not honesty; the goal is compatibility.

This is one of those annoying DOS details: software often checks DOS version not because it needs DOS 4, but because it wants to avoid unknown behavior.

## 8. File handles and path behavior

Implement a tiny handle table:

```c
#define MAX_HANDLES 20

struct Handle {
    bool used;
    bool device;
    uint8_t mode;
    uint32_t pos;
    uint32_t size;
    FatFile file;
};
```

Reserve handles:

```text
0 stdin  -> CON
1 stdout -> CON
2 stderr -> CON
3 stdaux -> AUX, can stub
4 stdprn -> PRN, can stub
```

Implement path parsing carefully:

```text
C:\MONKEY\MONKEY.EXE
\MONKEY\MONKEY.EXE
MONKEY.EXE
.\MONKEY.EXE
```

Rules you need:

* Case-insensitive 8.3 names.
* Backslash-separated paths.
* Current drive.
* Current directory.
* Wildcards for `FindFirst` / `FindNext`.
* File attributes, at least archive/read-only/directory.

A huge amount of DOS compatibility pain lives here, but for one game you can keep it manageable.

## 9. Memory control blocks

Implement a basic MCB chain because real DOS programs expect `INT 21h AH=48h/49h/4Ah` to behave like DOS.

Use the classic shape:

```text
MCB paragraph before block:
  signature: 'M' or 'Z'
  owner PSP segment
  size in paragraphs
  name, optional
```

Then allocation returns the segment immediately after the MCB.

Important behavior:

* `48h allocate`: best fit or first fit is fine at first.
* `49h free`: mark block free.
* `4Ah resize`: grow/shrink current block.
* Merge adjacent free blocks.
* Return DOS-like error codes with carry flag set.

You need enough conventional memory free for Monkey Island. Keep your kernel small and low.

## 10. Mouse and sound: defer, then add tiny shims

For the first “start” milestone, choose no sound during game setup if possible.

Sound is mostly direct hardware or driver-level behavior, not DOS. The DOS kernel usually does not “provide AdLib.” The game talks to hardware ports or uses a driver. So ignore sound until the game starts.

Mouse is different: DOS games commonly use `INT 33h`, which is normally provided by a mouse driver TSR. You can initially make `INT 33h AX=0000h` return “no mouse installed.” If Monkey Island starts but is awkward to control, add a tiny mouse-driver-compatible interrupt handler.

Minimum `INT 33h` later:

| Function   | Purpose                    |
| ---------- | -------------------------- |
| `AX=0000h` | reset / installation check |
| `AX=0001h` | show cursor                |
| `AX=0002h` | hide cursor                |
| `AX=0003h` | get position and buttons   |
| `AX=0004h` | set position               |
| `AX=0007h` | set horizontal range       |
| `AX=0008h` | set vertical range         |

You can fake mouse movement at first with keyboard arrows mapped to an internal mouse position.

## 11. Test strategy

Do not start by repeatedly booting Monkey Island and hoping. Build a ladder.

### Test group 1: tiny programs

Compile tiny 16-bit DOS test programs with Open Watcom:

```c
open/read/seek/close test
malloc/free/resize DOS memory test
findfirst/findnext test
get/set vector test
get version test
```

### Test group 2: known simple DOS utilities

Run very small `.COM` and `.EXE` programs that exercise one concept at a time.

Example progression:

```text
HELLO.COM
HELLO.EXE
READFILE.EXE
DIRLIKE.EXE
MEMTEST.EXE
EXECCHILD.EXE
```

### Test group 3: Monkey Island installer or executable

Skip installer initially. Install the game under real DOS, FreeDOS, or DOSBox, then copy the finished `C:\MONKEY` directory onto your disk image.

Try:

```text
C:\MONKEY\MONKEY.EXE
```

or whatever the actual executable name is in your release.

When it crashes, inspect the last missing interrupt call or bad file operation.

## 12. Debugging instrumentation

Add a serial log from day one. In Bochs/QEMU, logging to COM1 is much less annoying than printing to the screen after the game switches video modes.

Log:

```text
boot progress
FAT opens
file reads/seeks
EXEC load address
MZ relocation count
INT 21h calls
allocation/free/resize
unhandled interrupts
termination code
```

Example log lines:

```text
EXEC C:\MONKEY\MONKEY.EXE
MZ load: psp=12A0 image=12B0 relocs=183 min=04A2 max=FFFF
INT21 3D open DS:DX=14F0:0082 "MONKEY.001" mode=0 -> handle=5
INT21 3F read h=5 len=4096 -> 4096
INT21 48 alloc paras=2000 -> 3A20
UNHANDLED INT21 AX=4400 BX=0001 CX=0000 DX=0000
```

That log becomes your implementation roadmap.

## 13. First implementation sequence

I would build in this order:

### Phase 1 — Bootable kernel

Deliverable:

```text
Boots.
Loads KERNEL.SYS.
Prints memory size.
Can read files from FAT.
```

### Phase 2 — `.COM` loader

Deliverable:

```text
Can run HELLO.COM.
INT 20h and INT 21h AH=4Ch terminate correctly.
```

### Phase 3 — MZ `.EXE` loader

Deliverable:

```text
Can run HELLO.EXE.
Can relocate an EXE.
Can set PSP, stack, CS:IP, SS:SP.
```

### Phase 4 — filesystem handles

Deliverable:

```text
Can run a test EXE that opens, reads, seeks, and closes files.
FindFirst/FindNext work for C:\MONKEY\*.*.
```

### Phase 5 — DOS memory allocator

Deliverable:

```text
Can run a test EXE that allocates, resizes, frees.
MCB chain survives.
Largest-free-block reporting is plausible.
```

### Phase 6 — direct boot into Monkey Island

Deliverable:

```text
Kernel directly EXECs C:\MONKEY\MONKEY.EXE.
Missing INT 21h calls are logged.
No shell needed.
```

### Phase 7 — implement missing calls until visible start

Deliverable:

```text
Game reaches visible startup screen.
Keyboard works.
No sound required.
Mouse may report absent.
```

### Phase 8 — mouse shim

Deliverable:

```text
INT 33h exists.
Game sees a mouse.
Pointer position/buttons work well enough.
```

### Phase 9 — save-game writes

Deliverable:

```text
Create/write/close/rename/date functions work.
Save and load work.
```

## 14. What to borrow conceptually, not necessarily code

Use these as references:

* **MS-DOS 4.00 source** for structure and historical behavior, especially PSP, MCBs, and loader ideas; Microsoft’s release is MIT. ([opensource.microsoft.com][6])
* **FreeDOS kernel** for understanding what a modern compatible kernel has to cover, but be mindful that the FreeDOS kernel is GPL. ([GitHub][7])
* **Ralf Brown’s Interrupt List** for exact register behavior and weird interrupt details. ([ctyme.com][9])
* **Open Watcom docs** for compiling/linking your own 16-bit DOS test programs. ([open-watcom.github.io][4])

## 15. The “probably enough to start Monkey Island” checklist

Before even trying the game, your DOS should have:

```text
[ ] Boot from FAT image
[ ] Load KERNEL.SYS
[ ] Install INT 21h
[ ] Read files by path
[ ] Open/read/seek/close handles
[ ] Current drive and current directory
[ ] DTA support
[ ] FindFirst/FindNext
[ ] MZ EXE loader
[ ] PSP creation
[ ] Environment block
[ ] MCB allocator
[ ] Get/set interrupt vector
[ ] Get DOS version
[ ] Get date/time
[ ] Terminate program
[ ] Serial debug logging
```

Then try Monkey Island.

## 16. One important shortcut

For the first prototype, do **not** implement a real shell.

Have your kernel do this:

```c
kernel_main() {
    init_memory();
    init_fat();
    init_dos_interrupts();
    set_current_drive('C');
    set_current_directory("\\MONKEY");
    dos_exec("\\MONKEY\\MONKEY.EXE", "");
    panic("MONKEY returned");
}
```

A shell is nice, but it does not help you start the game. Add a `COMMAND.COM`-like shell later.

## 17. Difficulty estimate

For an experienced low-level programmer with AI assistance:

```text
Boot + FAT read + kernel load:        1–3 weeks
COM + simple EXE loading:             1–3 weeks
MZ loader + PSP + MCBs:               2–5 weeks
Enough INT 21h for test programs:     2–6 weeks
Monkey Island startup debugging:      2–8+ weeks
Mouse/save polish:                    2–6 weeks
```

So: **a few months for “Monkey Island starts” is plausible** if you keep the scope narrow. A general-purpose DOS replacement is a much larger project.

The most important discipline is this: every time you are tempted to implement “all of DOS,” instead run Monkey Island, log the missing behavior, and implement only the next thing it actually needs.

[1]: https://www.dosdays.co.uk/topics/Games/game_monkey.php "DOS Days - The Secret of Monkey Island (1990)"
[2]: https://bochs.sourceforge.io/ "bochs: The Open Source IA-32 Emulation Project (Home Page)"
[3]: https://www.nasm.us/ "NASM"
[4]: https://open-watcom.github.io/open-watcom-1.9/c_readme.html " Open Watcom 1.9 C/C++ Getting Started "
[5]: https://open-watcom.github.io/open-watcom-v2-wikidocs/lguide.html " Open Watcom 2.0 Linker Guide "
[6]: https://opensource.microsoft.com/blog/2024/04/25/open-sourcing-ms-dos-4-0/?utm_source=chatgpt.com "Open sourcing MS-DOS 4.0"
[7]: https://github.com/fdos/kernel "GitHub - FDOS/kernel: FreeDOS kernel - implements the core MS-DOS/PC-DOS (R) compatible operating system. It is derived from Pat Villani's DOS-C kernel and released under the GPL v2 or later. Please see http://www.freedos.org/ for more details about the FreeDOS (TM) Project. · GitHub"
[8]: https://wiki.osdev.org/Ralf_Brown%27s_Interrupt_List "Ralf Brown's Interrupt List - OSDev Wiki"
[9]: https://www.ctyme.com/rbrown.htm "Ralf Brown's Interrupt List - HTML Version"

