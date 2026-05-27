NASM := nasm
QEMU := qemu-system-i386
PYTHON := python3
RUN_TEST := $(PYTHON) scripts/run_test.py
TEST_JOBS ?= 4

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
FREECOM   := $(BUILDDIR)/free.com
DOSSTRUCT := $(BUILDDIR)/dosstruct.com
TESTFILE  := $(BUILDDIR)/testfile.dat
SUBTEST   := $(BUILDDIR)/subtest.dat
DISK_IMG := $(BUILDDIR)/disk.img

.PHONY: all clean run test test-serial test-monkey-full

all: $(DISK_IMG)

$(BOOT_BIN): $(SRCDIR)/boot.asm $(SRCDIR)/memory.inc
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(KERNEL_BIN): $(SRCDIR)/kernel.asm $(SRCDIR)/memory.inc $(SRCDIR)/kernel/mouse.inc $(SRCDIR)/kernel/console.inc $(SRCDIR)/kernel/memory_mcb.inc $(SRCDIR)/kernel/fat.inc $(SRCDIR)/kernel/disk.inc $(SRCDIR)/kernel/fs.inc $(SRCDIR)/kernel/exec.inc $(SRCDIR)/kernel/int21.inc
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

$(FREECOM): $(SRCDIR)/free.asm $(SRCDIR)/memory.inc
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(DOSSTRUCT): $(SRCDIR)/dosstruct.asm $(SRCDIR)/memory.inc
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(TESTFILE): scripts/mktestfile.py
	@mkdir -p $(BUILDDIR)
	$(PYTHON) $< $@

$(SUBTEST): scripts/mksubtest.py
	@mkdir -p $(BUILDDIR)
	$(PYTHON) $< $@

$(DISK_IMG): $(BOOT_BIN) $(KERNEL_BIN) $(HELLO_COM) $(HELLO_EXE) $(FILETEST) $(MEMTEST) $(CLOSETEST) $(REGTEST) $(MOUSETEST) $(MOUSEHW) $(MIIOTEST) $(WRITETEST) $(BIGRELOC) $(KEYTEST) $(EXTKEY) $(TIMETEST) $(OVLTEST) $(OVERLAY) $(SHELLCOM) $(EXECTEST) $(PSPTEST) $(PSPCHILD) $(CONSOLETEST) $(SAVEWR) $(DIRMUT) $(READWRAP) $(FREECOM) $(TESTFILE) $(SUBTEST)
	$(PYTHON) scripts/mkimage.py $< $(KERNEL_BIN) $@ $(HELLO_COM) $(HELLO_EXE) $(FILETEST) $(MEMTEST) $(CLOSETEST) $(REGTEST) $(MOUSETEST) $(MOUSEHW) $(MIIOTEST) $(WRITETEST) $(BIGRELOC) $(KEYTEST) $(EXTKEY) $(TIMETEST) $(OVLTEST) $(OVERLAY) $(SHELLCOM) $(EXECTEST) $(PSPTEST) $(PSPCHILD) $(CONSOLETEST) $(SAVEWR) $(DIRMUT) $(READWRAP) $(FREECOM) $(TESTFILE) MIDEMO:$(SUBTEST)

run: $(DISK_IMG)
	$(QEMU) -drive file=$(DISK_IMG),format=raw,if=floppy -boot order=a -serial stdio -monitor none -nographic

test: $(DISK_IMG)
	$(PYTHON) scripts/run_tests.py -j $(TEST_JOBS)

test-serial: TEST_JOBS := 1
test-serial: test

test-monkey-full: vendor/monkey_full.zip
	$(RUN_TEST) $(PYTHON) scripts/test_monkey_full.py

clean:
	rm -rf $(BUILDDIR)
