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
TESTFILE  := $(BUILDDIR)/testfile.dat
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

$(TESTFILE): scripts/mktestfile.py
	@mkdir -p $(BUILDDIR)
	$(PYTHON) $< $@

$(DISK_IMG): $(BOOT_BIN) $(KERNEL_BIN) $(HELLO_COM) $(HELLO_EXE) $(FILETEST) $(MEMTEST) $(CLOSETEST) $(REGTEST) $(MOUSETEST) $(MOUSEHW) $(TESTFILE)
	$(PYTHON) scripts/mkimage.py $< $(KERNEL_BIN) $@ $(HELLO_COM) $(HELLO_EXE) $(FILETEST) $(MEMTEST) $(CLOSETEST) $(REGTEST) $(MOUSETEST) $(MOUSEHW) $(TESTFILE) MIDEMO:build/subtest.dat

run: $(DISK_IMG)
	$(QEMU) -drive file=$(DISK_IMG),format=raw,if=floppy -boot order=a -serial stdio -monitor none -nographic

test: $(DISK_IMG)
	$(PYTHON) scripts/test_boot.py

clean:
	rm -rf $(BUILDDIR)
