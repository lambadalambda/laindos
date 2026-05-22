NASM := nasm
QEMU := qemu-system-i386
PYTHON := python3

SRCDIR := src
BUILDDIR := build

BOOT_BIN := $(BUILDDIR)/boot.bin
KERNEL_BIN := $(BUILDDIR)/kernel.bin
HELLO_COM := $(BUILDDIR)/hello.com
HELLO_EXE := $(BUILDDIR)/hello.exe
FILETEST  := $(BUILDDIR)/filetest.exe
MEMTEST   := $(BUILDDIR)/memtest.exe
CLOSETEST := $(BUILDDIR)/close.exe
REGTEST   := $(BUILDDIR)/regtest.exe
MOUSETEST := $(BUILDDIR)/mouse.exe
MOUSEHW   := $(BUILDDIR)/mousehw.exe
MIIOTEST  := $(BUILDDIR)/miiotest.exe
WRITETEST := $(BUILDDIR)/write.exe
BIGRELOC  := $(BUILDDIR)/bigreloc.exe
KEYTEST   := $(BUILDDIR)/keytest.com
OVLTEST   := $(BUILDDIR)/ovltest.com
OVERLAY   := $(BUILDDIR)/overlay.exe
SHELLCOM  := $(BUILDDIR)/shell.com
EXECTEST  := $(BUILDDIR)/exectest.com
CONSOLETEST := $(BUILDDIR)/console.com
SAVEWR    := $(BUILDDIR)/savewr.com
TESTFILE  := $(BUILDDIR)/testfile.dat
SUBTEST   := $(BUILDDIR)/subtest.dat
DISK_IMG := $(BUILDDIR)/disk.img

.PHONY: all clean run test

all: $(DISK_IMG)

$(BOOT_BIN): $(SRCDIR)/boot.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(KERNEL_BIN): $(SRCDIR)/kernel.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(HELLO_COM): $(SRCDIR)/hello.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(HELLO_EXE): $(SRCDIR)/helloexe.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(FILETEST): $(SRCDIR)/filetest.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(MEMTEST): $(SRCDIR)/memtest.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(CLOSETEST): $(SRCDIR)/closetest.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(REGTEST): $(SRCDIR)/regtest.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(MOUSETEST): $(SRCDIR)/mousetest.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(MOUSEHW): $(SRCDIR)/mousehw.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(MIIOTEST): $(SRCDIR)/miiotest.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(WRITETEST): $(SRCDIR)/writetest.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(BIGRELOC): $(SRCDIR)/bigreloc.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(KEYTEST): $(SRCDIR)/keytest.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(OVLTEST): $(SRCDIR)/ovltest.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(OVERLAY): $(SRCDIR)/overlay.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(SHELLCOM): $(SRCDIR)/shell.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(EXECTEST): $(SRCDIR)/exectest.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(CONSOLETEST): $(SRCDIR)/consoletest.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(SAVEWR): $(SRCDIR)/savewr.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(TESTFILE): scripts/mktestfile.py
	@mkdir -p $(BUILDDIR)
	$(PYTHON) $< $@

$(SUBTEST): scripts/mksubtest.py
	@mkdir -p $(BUILDDIR)
	$(PYTHON) $< $@

$(DISK_IMG): $(BOOT_BIN) $(KERNEL_BIN) $(HELLO_COM) $(HELLO_EXE) $(FILETEST) $(MEMTEST) $(CLOSETEST) $(REGTEST) $(MOUSETEST) $(MOUSEHW) $(MIIOTEST) $(WRITETEST) $(BIGRELOC) $(KEYTEST) $(OVLTEST) $(OVERLAY) $(SHELLCOM) $(EXECTEST) $(CONSOLETEST) $(SAVEWR) $(TESTFILE) $(SUBTEST)
	$(PYTHON) scripts/mkimage.py $< $(KERNEL_BIN) $@ $(HELLO_COM) $(HELLO_EXE) $(FILETEST) $(MEMTEST) $(CLOSETEST) $(REGTEST) $(MOUSETEST) $(MOUSEHW) $(MIIOTEST) $(WRITETEST) $(BIGRELOC) $(KEYTEST) $(OVLTEST) $(OVERLAY) $(SHELLCOM) $(EXECTEST) $(CONSOLETEST) $(SAVEWR) $(TESTFILE) MIDEMO:$(SUBTEST)

run: $(DISK_IMG)
	$(QEMU) -drive file=$(DISK_IMG),format=raw,if=floppy -boot order=a -serial stdio -monitor none -nographic

test: $(DISK_IMG)
	$(PYTHON) scripts/test_boot.py
	$(PYTHON) scripts/test_write.py
	$(PYTHON) scripts/test_bigreloc.py
	$(PYTHON) scripts/test_keyboard.py
	$(PYTHON) scripts/test_overlay.py
	$(PYTHON) scripts/test_shell.py
	$(PYTHON) scripts/test_console.py
	$(PYTHON) scripts/test_savewrite.py

clean:
	rm -rf $(BUILDDIR)
