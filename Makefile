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
EXTKEY    := $(BUILDDIR)/extkey.com
TIMETEST  := $(BUILDDIR)/timetest.com
OVLTEST   := $(BUILDDIR)/ovltest.com
OVERLAY   := $(BUILDDIR)/overlay.exe
SHELLCOM  := $(BUILDDIR)/shell.com
EXECTEST  := $(BUILDDIR)/exectest.com
PSPTEST   := $(BUILDDIR)/psptest.com
PSPCHILD  := $(BUILDDIR)/pspchild.com
CONSOLETEST := $(BUILDDIR)/console.com
SAVEWR    := $(BUILDDIR)/savewr.com
DIRMUT    := $(BUILDDIR)/dirmut.com
READWRAP  := $(BUILDDIR)/readwrap.exe
TESTFILE  := $(BUILDDIR)/testfile.dat
SUBTEST   := $(BUILDDIR)/subtest.dat
DISK_IMG := $(BUILDDIR)/disk.img

.PHONY: all clean run test test-monkey-full

all: $(DISK_IMG)

$(BOOT_BIN): $(SRCDIR)/boot.asm $(SRCDIR)/memory.inc
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(KERNEL_BIN): $(SRCDIR)/kernel.asm $(SRCDIR)/memory.inc
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

$(EXTKEY): $(SRCDIR)/extkey.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(TIMETEST): $(SRCDIR)/timetest.asm
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

$(PSPTEST): $(SRCDIR)/psptest.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(PSPCHILD): $(SRCDIR)/pspchild.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(CONSOLETEST): $(SRCDIR)/consoletest.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(SAVEWR): $(SRCDIR)/savewr.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(DIRMUT): $(SRCDIR)/dirmut.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(READWRAP): $(SRCDIR)/readwrap.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(TESTFILE): scripts/mktestfile.py
	@mkdir -p $(BUILDDIR)
	$(PYTHON) $< $@

$(SUBTEST): scripts/mksubtest.py
	@mkdir -p $(BUILDDIR)
	$(PYTHON) $< $@

$(DISK_IMG): $(BOOT_BIN) $(KERNEL_BIN) $(HELLO_COM) $(HELLO_EXE) $(FILETEST) $(MEMTEST) $(CLOSETEST) $(REGTEST) $(MOUSETEST) $(MOUSEHW) $(MIIOTEST) $(WRITETEST) $(BIGRELOC) $(KEYTEST) $(EXTKEY) $(TIMETEST) $(OVLTEST) $(OVERLAY) $(SHELLCOM) $(EXECTEST) $(PSPTEST) $(PSPCHILD) $(CONSOLETEST) $(SAVEWR) $(DIRMUT) $(READWRAP) $(TESTFILE) $(SUBTEST)
	$(PYTHON) scripts/mkimage.py $< $(KERNEL_BIN) $@ $(HELLO_COM) $(HELLO_EXE) $(FILETEST) $(MEMTEST) $(CLOSETEST) $(REGTEST) $(MOUSETEST) $(MOUSEHW) $(MIIOTEST) $(WRITETEST) $(BIGRELOC) $(KEYTEST) $(EXTKEY) $(TIMETEST) $(OVLTEST) $(OVERLAY) $(SHELLCOM) $(EXECTEST) $(PSPTEST) $(PSPCHILD) $(CONSOLETEST) $(SAVEWR) $(DIRMUT) $(READWRAP) $(TESTFILE) MIDEMO:$(SUBTEST)

run: $(DISK_IMG)
	$(QEMU) -drive file=$(DISK_IMG),format=raw,if=floppy -boot order=a -serial stdio -monitor none -nographic

test: $(DISK_IMG)
	$(PYTHON) scripts/test_autoexec.py
	$(PYTHON) scripts/test_boot.py
	$(PYTHON) scripts/test_highmcb.py
	$(PYTHON) scripts/test_write.py
	$(PYTHON) scripts/test_bigreloc.py
	$(PYTHON) scripts/test_keyboard.py
	$(PYTHON) scripts/test_overlay.py
	$(PYTHON) scripts/test_shell.py
	$(PYTHON) scripts/test_console.py
	$(PYTHON) scripts/test_devnames.py
	$(PYTHON) scripts/test_diskfree.py
	$(PYTHON) scripts/test_dirextfail.py
	$(PYTHON) scripts/test_envpath.py
	$(PYTHON) scripts/test_findattr.py
	$(PYTHON) scripts/test_findnext.py
	$(PYTHON) scripts/test_findtime.py
	$(PYTHON) scripts/test_readcache.py
	$(PYTHON) scripts/test_regpres.py
	$(PYTHON) scripts/test_savewrite.py
	$(PYTHON) scripts/test_termflush.py
	$(PYTHON) scripts/test_dirmut.py
	$(PYTHON) scripts/test_readwrap.py

test-monkey-full: vendor/monkey_full.zip
	$(PYTHON) scripts/test_monkey_full.py

clean:
	rm -rf $(BUILDDIR)
