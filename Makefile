NASM := nasm
QEMU := qemu-system-i386
PYTHON := python3

SRCDIR := src
BUILDDIR := build

BOOT_BIN := $(BUILDDIR)/boot.bin
KERNEL_BIN := $(BUILDDIR)/kernel.bin
HELLO_COM := $(BUILDDIR)/hello.com
HELLO_EXE := $(BUILDDIR)/hello.exe
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

$(DISK_IMG): $(BOOT_BIN) $(KERNEL_BIN) $(HELLO_COM) $(HELLO_EXE)
	$(PYTHON) scripts/mkimage.py $< $(KERNEL_BIN) $@ $(HELLO_COM) $(HELLO_EXE)

run: $(DISK_IMG)
	$(QEMU) -drive file=$(DISK_IMG),format=raw,if=floppy -boot order=a -serial stdio -monitor none -nographic

test: $(DISK_IMG)
	$(PYTHON) scripts/test_boot.py

clean:
	rm -rf $(BUILDDIR)
