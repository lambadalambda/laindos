NASM := nasm
PATCHED_QEMU := $(abspath ../qemu-ascendancy/build-asc/qemu-system-i386-unsigned)
DEFAULT_QEMU_VGA := std,retrace=precise
QEMU ?= $(if $(LAINDOS_QEMU),$(LAINDOS_QEMU),$(if $(wildcard $(PATCHED_QEMU)),$(PATCHED_QEMU),qemu-system-i386))
QEMU_VGA ?= $(if $(LAINDOS_QEMU_VGA),$(LAINDOS_QEMU_VGA),$(DEFAULT_QEMU_VGA))
QEMU_SOUND ?= -device sb16
PYTHON := python3
RUN_TEST := $(PYTHON) scripts/run_test.py
TEST_JOBS ?= 4

SRCDIR := src
PROGRAMDIR := programs
TEST_PROGRAMDIR := tests/programs
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
MEMCOM    := $(BUILDDIR)/mem.com
TIMECOM   := $(BUILDDIR)/time.com
DOSSTRUCT := $(BUILDDIR)/dosstruct.com
CTRUNCTEST := $(BUILDDIR)/ctrunc.com
RNGUARDTEST := $(BUILDDIR)/rnguard.com
BADRELOCTEST := $(BUILDDIR)/badreloc.com
BADRELOCEXE := $(BUILDDIR)/badreloc.exe
TESTFILE  := $(BUILDDIR)/testfile.dat
SUBTEST   := $(BUILDDIR)/subtest.dat
DISK_IMG := $(BUILDDIR)/disk.img
MONKEY_DEMO_FILES := vendor/midemo.exe vendor/disk01.lec vendor/000.lfl vendor/901.lfl vendor/902.lfl vendor/904.lfl vendor/monkey.txt vendor/readme
NIGHTLY_PACKAGE := $(BUILDDIR)/laindos-monkey-demo-nightly.zip
DEFAULT_SITE_IMAGE := $(BUILDDIR)/shell_monkey.img
SITE_IMAGE_DEPS :=
ifeq ($(origin SITE_IMAGE),undefined)
SITE_IMAGE := $(DEFAULT_SITE_IMAGE)
SITE_IMAGE_DEPS := monkey-demo
endif
SITE_IMAGE_ARG := $(if $(SITE_IMAGE),--image $(SITE_IMAGE),)

.PHONY: all clean run site check-docs-sync test test-serial monkey-demo nightly-package run-monkey-demo test-monkey-demo test-attached-hd-shell extras-hd run-extras-hd test-cd-bios test-cd-file test-cd-subdir test-cd-find test-cd-mscdex test-monkey-full test-wolf3d-smoke test-ascendancy-smoke test-norton-commander-smoke test-norton-commander-launch test-norton-commander-copy test-norton-commander-rename-delete test-norton-commander-mkdir-rmdir test-norton-commander test-shortline-smoke test-game-smokes

all: $(DISK_IMG)

$(BOOT_BIN): $(SRCDIR)/boot.asm $(SRCDIR)/memory.inc $(SRCDIR)/fat_bpb.inc
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin -DFAT12=1 $< -o $@

$(KERNEL_BIN): $(SRCDIR)/kernel.asm $(SRCDIR)/memory.inc $(SRCDIR)/kernel/mouse.inc $(SRCDIR)/kernel/console.inc $(SRCDIR)/kernel/memory_mcb.inc $(SRCDIR)/kernel/path_dir.inc $(SRCDIR)/kernel/cdrom.inc $(SRCDIR)/kernel/fat.inc $(SRCDIR)/kernel/disk.inc $(SRCDIR)/kernel/fs.inc $(SRCDIR)/kernel/exec.inc $(SRCDIR)/kernel/int21.inc
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(HELLO_COM): $(TEST_PROGRAMDIR)/hello.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(HELLO_EXE): $(TEST_PROGRAMDIR)/helloexe.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(FILETEST): $(TEST_PROGRAMDIR)/filetest.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(MEMTEST): $(TEST_PROGRAMDIR)/memtest.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(CLOSETEST): $(TEST_PROGRAMDIR)/closetest.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(REGTEST): $(TEST_PROGRAMDIR)/regtest.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(MOUSETEST): $(TEST_PROGRAMDIR)/mousetest.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(MOUSEHW): $(TEST_PROGRAMDIR)/mousehw.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(MIIOTEST): $(TEST_PROGRAMDIR)/miiotest.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(WRITETEST): $(TEST_PROGRAMDIR)/writetest.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(BIGRELOC): $(TEST_PROGRAMDIR)/bigreloc.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(KEYTEST): $(TEST_PROGRAMDIR)/keytest.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(EXTKEY): $(TEST_PROGRAMDIR)/extkey.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(TIMETEST): $(TEST_PROGRAMDIR)/timetest.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(OVLTEST): $(TEST_PROGRAMDIR)/ovltest.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(OVERLAY): $(TEST_PROGRAMDIR)/overlay.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(SHELLCOM): $(PROGRAMDIR)/shell.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(EXECTEST): $(TEST_PROGRAMDIR)/exectest.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(PSPTEST): $(TEST_PROGRAMDIR)/psptest.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(PSPCHILD): $(TEST_PROGRAMDIR)/pspchild.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(CONSOLETEST): $(TEST_PROGRAMDIR)/consoletest.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(SAVEWR): $(TEST_PROGRAMDIR)/savewr.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(DIRMUT): $(TEST_PROGRAMDIR)/dirmut.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(READWRAP): $(TEST_PROGRAMDIR)/readwrap.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(FREECOM): $(PROGRAMDIR)/free.asm $(SRCDIR)/memory.inc
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(MEMCOM): $(PROGRAMDIR)/free.asm $(SRCDIR)/memory.inc
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(TIMECOM): $(PROGRAMDIR)/time.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(DOSSTRUCT): $(TEST_PROGRAMDIR)/dosstruct.asm $(SRCDIR)/memory.inc
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(CTRUNCTEST): $(TEST_PROGRAMDIR)/ctrunc.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(RNGUARDTEST): $(TEST_PROGRAMDIR)/rnguard.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(BADRELOCTEST): $(TEST_PROGRAMDIR)/badreloc.asm
	@mkdir -p $(BUILDDIR)
	$(NASM) -f bin $< -o $@

$(BADRELOCEXE): scripts/mkbadreloc.py
	@mkdir -p $(BUILDDIR)
	$(PYTHON) $< $@

$(TESTFILE): scripts/mktestfile.py
	@mkdir -p $(BUILDDIR)
	$(PYTHON) $< $@

$(SUBTEST): scripts/mksubtest.py
	@mkdir -p $(BUILDDIR)
	$(PYTHON) $< $@

$(DISK_IMG): $(BOOT_BIN) $(KERNEL_BIN) $(HELLO_COM) $(HELLO_EXE) $(FILETEST) $(MEMTEST) $(CLOSETEST) $(REGTEST) $(MOUSETEST) $(MOUSEHW) $(MIIOTEST) $(WRITETEST) $(BIGRELOC) $(KEYTEST) $(EXTKEY) $(TIMETEST) $(OVLTEST) $(OVERLAY) $(SHELLCOM) $(EXECTEST) $(PSPTEST) $(PSPCHILD) $(CONSOLETEST) $(SAVEWR) $(DIRMUT) $(READWRAP) $(FREECOM) $(MEMCOM) $(TIMECOM) $(CTRUNCTEST) $(RNGUARDTEST) $(BADRELOCTEST) $(BADRELOCEXE) $(TESTFILE) $(SUBTEST)
	$(PYTHON) scripts/mkimage.py $< $(KERNEL_BIN) $@ $(HELLO_COM) $(HELLO_EXE) $(FILETEST) $(MEMTEST) $(CLOSETEST) $(REGTEST) $(MOUSETEST) $(MOUSEHW) $(MIIOTEST) $(WRITETEST) $(BIGRELOC) $(KEYTEST) $(EXTKEY) $(TIMETEST) $(OVLTEST) $(OVERLAY) $(SHELLCOM) $(EXECTEST) $(PSPTEST) $(PSPCHILD) $(CONSOLETEST) $(SAVEWR) $(DIRMUT) $(READWRAP) $(FREECOM) $(MEMCOM) $(TIMECOM) $(CTRUNCTEST) $(RNGUARDTEST) $(BADRELOCTEST) $(BADRELOCEXE) $(TESTFILE) MIDEMO:$(SUBTEST)

run: $(DISK_IMG)
	$(QEMU) -drive file=$(DISK_IMG),format=raw,if=floppy -boot order=a -serial stdio -monitor none -vga $(QEMU_VGA) -nographic

site: $(SITE_IMAGE_DEPS)
	deno run --allow-read=. --allow-write=$(BUILDDIR) --allow-run=deno,python3 scripts/build_site.jsx --out $(BUILDDIR)/site $(SITE_IMAGE_ARG)

check-docs-sync:
	$(PYTHON) scripts/check_docs_sync.py

test: $(DISK_IMG) check-docs-sync
	$(PYTHON) scripts/run_tests.py -j $(TEST_JOBS)

test-serial: TEST_JOBS := 1
test-serial: test

monkey-demo: $(MONKEY_DEMO_FILES)
	$(PYTHON) scripts/build_shell_monkey.py

nightly-package: monkey-demo
	$(PYTHON) scripts/package_nightly.py

run-monkey-demo: monkey-demo
	$(QEMU) -drive file=$(BUILDDIR)/shell_monkey.img,format=raw,if=floppy -boot order=a -serial stdio -monitor none -vga $(QEMU_VGA) $(QEMU_SOUND)

test-monkey-demo: $(MONKEY_DEMO_FILES)
	$(RUN_TEST) $(PYTHON) scripts/test_shell_monkey.py

test-attached-hd-shell: $(MONKEY_DEMO_FILES)
	$(RUN_TEST) $(PYTHON) scripts/test_attached_hd_shell.py

test-cd-bios:
	$(RUN_TEST) $(PYTHON) scripts/test_cd_bios.py

test-cd-file:
	$(RUN_TEST) $(PYTHON) scripts/test_cd_file.py

test-cd-subdir:
	$(RUN_TEST) $(PYTHON) scripts/test_cd_subdir.py

test-cd-find:
	$(RUN_TEST) $(PYTHON) scripts/test_cd_find.py

test-cd-mscdex:
	$(RUN_TEST) $(PYTHON) scripts/test_cd_mscdex.py

extras-hd: $(MONKEY_DEMO_FILES) vendor/monkey_full.zip vendor/mi2demo.zip vendor/Monkey_Island_2_-_LeChucks_Revenge_1991.zip vendor/simon1demo.zip vendor/Ascendancy_1995.zip vendor/wolf3dsw.zip vendor/003064_norton_commander.7z vendor/sid-meiers-civilization-au.zip vendor/002514_stunt_island.7z
	$(PYTHON) scripts/build_extras_hd.py

run-extras-hd: extras-hd
	$(QEMU) -drive file=$(BUILDDIR)/extras_hd.img,format=raw -boot order=c -serial stdio -monitor none -vga $(QEMU_VGA) $(QEMU_SOUND)

test-monkey-full: vendor/monkey_full.zip
	$(RUN_TEST) $(PYTHON) scripts/test_monkey_full.py

test-wolf3d-smoke: vendor/wolf3dsw.zip
	$(RUN_TEST) $(PYTHON) scripts/test_wolf3d_smoke.py

test-ascendancy-smoke: vendor/Ascendancy_1995.zip
	$(RUN_TEST) $(PYTHON) scripts/test_ascendancy_smoke.py

test-norton-commander-smoke: vendor/003064_norton_commander.7z
	$(RUN_TEST) $(PYTHON) scripts/test_norton_commander_smoke.py

test-norton-commander-launch: vendor/003064_norton_commander.7z
	$(RUN_TEST) $(PYTHON) scripts/test_norton_commander_launch.py

test-norton-commander-copy: vendor/003064_norton_commander.7z
	$(RUN_TEST) $(PYTHON) scripts/test_norton_commander_copy.py

test-norton-commander-rename-delete: vendor/003064_norton_commander.7z
	$(RUN_TEST) $(PYTHON) scripts/test_norton_commander_rename_delete.py

test-norton-commander-mkdir-rmdir: vendor/003064_norton_commander.7z
	$(RUN_TEST) $(PYTHON) scripts/test_norton_commander_mkdir_rmdir.py

test-norton-commander: test-norton-commander-smoke test-norton-commander-launch test-norton-commander-copy test-norton-commander-rename-delete test-norton-commander-mkdir-rmdir

test-shortline-smoke: vendor/SHRTLINE.zip
	$(RUN_TEST) $(PYTHON) scripts/test_shortline_smoke.py

test-game-smokes: test-monkey-demo test-monkey-full test-wolf3d-smoke test-ascendancy-smoke

clean:
	rm -rf $(BUILDDIR)
