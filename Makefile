NASM := nasm
QEMU := qemu-system-i386
PYTHON := python3

SRCDIR := src
BUILDDIR := build

BOOT_BIN := $(BUILDDIR)/boot.bin
KERNEL_BIN := $(BUILDDIR)/kernel.bin
DISK_IMG := $(BUILDDIR)/disk.img

.PHONY: all clean run

all: $(DISK_IMG)

$(BOOT_BIN): $(SRCDIR)/boot.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(KERNEL_BIN): $(SRCDIR)/kernel.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(DISK_IMG): $(BOOT_BIN) $(KERNEL_BIN)
	$(PYTHON) scripts/mkimage.py $< $(KERNEL_BIN) $@

run: $(DISK_IMG)
	$(QEMU) -drive file=$(DISK_IMG),format=raw,if=floppy -boot order=a -serial stdio -monitor none -nographic

clean:
	rm -rf $(BUILDDIR)
