#!/usr/bin/env python3
import os
import re
import socket
import subprocess
import sys
import time
import build_shell_com
from testlib import run_cmd, build_dir, finish_qemu, start_qemu, wait_for_output

QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "shelltest.img")
KERNEL = os.path.join(BUILDDIR, "shelltest_kernel.bin")
MONITOR = os.path.join(BUILDDIR, "shelltest.sock")
KEY_DELAY = 0.02
KEY_HOLD_MS = 10
PROMPT_RE = re.compile(rb"A:\\[^>\r\n]*>")
KEYMAP = {" ": "spc", "\\": "backslash", ".": "dot", "/": "slash", "-": "minus", "_": "shift-minus", ":": "shift-semicolon", "*": "shift-8"}


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", os.path.join(BUILDDIR, "boot.bin")])
    run_cmd([
        "nasm", '-DBOOT_FILE="SHELL   COM"', "-f", "bin", "src/kernel.asm",
        "-o", KERNEL,
    ])
    run_cmd(["python3", "scripts/build_shell_com.py", os.path.join(BUILDDIR, "shell.com")])
    run_cmd(["nasm", "-f", "bin", "tests/programs/hello.asm", "-o", os.path.join(BUILDDIR, "hello.com")])
    run_cmd(["nasm", "-f", "bin", "tests/programs/helloexe.asm", "-o", os.path.join(BUILDDIR, "helloexe.exe")])
    run_cmd(["nasm", "-f", "bin", "tests/programs/exectest.asm", "-o", os.path.join(BUILDDIR, "exectest.com")])
    run_cmd(["nasm", "-f", "bin", "tests/programs/psptest.asm", "-o", os.path.join(BUILDDIR, "psptest.com")])
    run_cmd(["nasm", "-f", "bin", "tests/programs/pspchild.asm", "-o", os.path.join(BUILDDIR, "pspchild.com")])
    run_cmd(["nasm", "-f", "bin", "tests/programs/keytest.asm", "-o", os.path.join(BUILDDIR, "keytest.com")])
    run_cmd(["nasm", "-f", "bin", "tests/programs/extkey.asm", "-o", os.path.join(BUILDDIR, "extkey.com")])
    run_cmd(["nasm", "-f", "bin", "tests/programs/timetest.asm", "-o", os.path.join(BUILDDIR, "timetest.com")])
    run_cmd(["nasm", "-f", "bin", "programs/time.asm", "-o", os.path.join(BUILDDIR, "time.com")])
    run_cmd(["nasm", "-f", "bin", "tests/programs/argtest.asm", "-o", os.path.join(BUILDDIR, "argtest.com")])
    run_cmd(["nasm", "-f", "bin", "tests/programs/argexe.asm", "-o", os.path.join(BUILDDIR, "argexe.exe")])
    run_cmd(["nasm", "-f", "bin", "tests/programs/exemax.asm", "-o", os.path.join(BUILDDIR, "exemax.exe")])
    run_cmd(["nasm", "-f", "bin", "tests/programs/memreg.asm", "-o", os.path.join(BUILDDIR, "memreg.com")])
    run_cmd(["nasm", "-f", "bin", "tests/programs/packseg.asm", "-o", os.path.join(BUILDDIR, "packseg.exe")])
    run_cmd(["nasm", "-f", "bin", "programs/free.asm", "-o", os.path.join(BUILDDIR, "free.com")])
    run_cmd(["nasm", "-f", "bin", "programs/free.asm", "-o", os.path.join(BUILDDIR, "mem.com")])
    run_cmd(["python3", "scripts/mktestfile.py", os.path.join(BUILDDIR, "testfile.dat")])
    run_cmd(["python3", "scripts/mksubtest.py", os.path.join(BUILDDIR, "subtest.dat")])
    with open(os.path.join(BUILDDIR, "testbat.bat"), "wb") as f:
        f.write(b"Echo off\r\nargtest GDEMO /3\r\nargexe GDEMO /3\r\nEcho on\r\n")
    run_cmd([
        "python3", "scripts/mkimage.py",
        os.path.join(BUILDDIR, "boot.bin"),
        KERNEL,
        IMG,
        os.path.join(BUILDDIR, "shell.com"),
        os.path.join(BUILDDIR, "hello.com"),
        os.path.join(BUILDDIR, "helloexe.exe"),
        os.path.join(BUILDDIR, "exectest.com"),
        os.path.join(BUILDDIR, "psptest.com"),
        os.path.join(BUILDDIR, "pspchild.com"),
        os.path.join(BUILDDIR, "keytest.com"),
        os.path.join(BUILDDIR, "extkey.com"),
        os.path.join(BUILDDIR, "timetest.com"),
        os.path.join(BUILDDIR, "time.com"),
        os.path.join(BUILDDIR, "argtest.com"),
        os.path.join(BUILDDIR, "argexe.exe"),
        os.path.join(BUILDDIR, "exemax.exe"),
        os.path.join(BUILDDIR, "memreg.com"),
        os.path.join(BUILDDIR, "packseg.exe"),
        os.path.join(BUILDDIR, "free.com"),
        os.path.join(BUILDDIR, "mem.com"),
        os.path.join(BUILDDIR, "testbat.bat"),
        os.path.join(BUILDDIR, "testfile.dat"),
        f"DIRONLY:{os.path.join(BUILDDIR, 'subtest.dat')}",
        f"MIDEMO:{os.path.join(BUILDDIR, 'helloexe.exe')}",
        f"MIDEMO:{os.path.join(BUILDDIR, 'subtest.dat')}",
    ])


def send_monitor_key(sock, key):
    sock.sendall(f"sendkey {key} {KEY_HOLD_MS}\n".encode())
    time.sleep(KEY_DELAY)


def prompt_count(output_chunks):
    return len(PROMPT_RE.findall(b"".join(output_chunks)))


def wait_for_prompt_count(output_chunks, count, timeout=8, context="prompt"):
    deadline = time.monotonic() + timeout
    stop_markers = ("FAIL:", "EXC ", "INT 21h AH=", "HALT")
    while time.monotonic() < deadline:
        output = b"".join(output_chunks)
        if len(PROMPT_RE.findall(output)) >= count:
            return
        for marker in stop_markers:
            if marker.encode() in output:
                raise RuntimeError(f"saw {marker!r} while waiting for {context}")
        time.sleep(0.02)
    raise TimeoutError(f"timed out waiting for {context}")


def send_text(sock, text):
    for ch in text:
        if ch.isalnum():
            key = ch.lower()
        elif ch in KEYMAP:
            key = KEYMAP[ch]
        else:
            raise ValueError(f"unmapped QEMU key for {ch!r} in {text!r}")
        send_monitor_key(sock, key)


def send_command(sock, output_chunks, command, timeout=8):
    target_prompt = prompt_count(output_chunks) + 1
    start_len = len(b"".join(output_chunks))
    send_text(sock, command)
    send_monitor_key(sock, "ret")
    wait_for_prompt_count(output_chunks, target_prompt, timeout=timeout, context=f"prompt after {command!r}")
    return b"".join(output_chunks)[start_len:]


def send_command_answer(sock, output_chunks, command, marker, answer, timeout=8):
    target_prompt = prompt_count(output_chunks) + 1
    start_len = len(b"".join(output_chunks))
    send_text(sock, command)
    send_monitor_key(sock, "ret")
    if not wait_for_output_since(output_chunks, marker, start_len, timeout=timeout):
        raise TimeoutError(f"timed out waiting for {marker!r} after {command!r}")
    send_text(sock, answer)
    wait_for_prompt_count(output_chunks, target_prompt, timeout=timeout, context=f"prompt after {command!r}")
    return b"".join(output_chunks)[start_len:]


def require_command_output(command, output, expected=(), unexpected=()):
    for marker in expected:
        if marker.encode() not in output:
            raise RuntimeError(f"{command!r} output missing {marker!r}: {output!r}")
    for marker in unexpected:
        if marker.encode() in output:
            raise RuntimeError(f"{command!r} output unexpectedly contained {marker!r}: {output!r}")


def wait_for_output_since(output_chunks, marker, start_len, timeout=8):
    marker = marker.encode()
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        output = b"".join(output_chunks)
        if marker in output[start_len:]:
            return True
        time.sleep(0.02)
    return False


def send_paged_dir(sock, output_chunks, command):
    target_prompt = prompt_count(output_chunks) + 1
    start_len = len(b"".join(output_chunks))
    send_text(sock, command)
    send_monitor_key(sock, "ret")
    if not wait_for_output_since(output_chunks, "Press any key to continue . . .", start_len, timeout=8):
        raise TimeoutError(f"timed out waiting for {command.upper()} prompt")
    send_monitor_key(sock, "spc")
    wait_for_prompt_count(output_chunks, target_prompt, timeout=8, context=f"prompt after {command.upper()}")


def send_keys(output_chunks):
    deadline = time.time() + 8
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    while True:
        try:
            sock.connect(MONITOR)
            break
        except OSError:
            if time.time() > deadline:
                raise
            time.sleep(0.1)
    sock.recv(4096)
    for command in ["ver", "cls", "dir", "type testfile.dat", "echo interactive echo", "rem interactive comment", "hello", "shell /c hello", "keytest"]:
        send_command(sock, output_chunks, command)
    send_paged_dir(sock, output_chunks, "dir /p")
    send_paged_dir(sock, output_chunks, "dir/p")

    dir_midemo = send_command(sock, output_chunks, "dir midemo")
    require_command_output("dir midemo", dir_midemo, ["Directory of A:\\midemo", "SUBTEST  DAT"])
    dir_midemo_dat = send_command(sock, output_chunks, "dir midemo\\*.dat")
    require_command_output("dir midemo\\*.dat", dir_midemo_dat, ["SUBTEST  DAT", "32 bytes (32 B)"], ["HELLOEXE EXE"])
    dir_com = send_command(sock, output_chunks, "dir *.com")
    require_command_output("dir *.com", dir_com, ["SHELL    COM", "HELLO    COM"], ["HELLOEXE EXE"])
    dir_wide = send_command(sock, output_chunks, "dir /w")
    require_command_output("dir /w", dir_wide, ["SHELL.COM", "[DIRONLY]"])
    if not re.search(rb"SHELL\.COM[^\r\n]+HELLO\.COM", dir_wide):
        raise RuntimeError("'dir /w' did not print multiple file names on one row")

    copy_new = send_command(sock, output_chunks, "copy testfile.dat copy1.dat")
    require_command_output("copy testfile.dat copy1.dat", copy_new, ["1 File(s) copied."])
    copy_self = send_command(sock, output_chunks, "copy testfile.dat testfile.dat")
    require_command_output("copy testfile.dat testfile.dat", copy_self,
                           ["File cannot be copied onto itself"],
                           ["1 File(s) copied."])
    copy_self_type = send_command(sock, output_chunks, "type testfile.dat")
    require_command_output("type testfile.dat after self-copy", copy_self_type,
                           ["Hello from TESTFILE.DAT! This is test data for LainDOS file I/O."])
    copy_new_type = send_command(sock, output_chunks, "type copy1.dat")
    require_command_output("type copy1.dat", copy_new_type, ["Hello from TESTFILE.DAT! This is test data for LainDOS file I/O."])
    copy_dir = send_command(sock, output_chunks, "copy testfile.dat dironly")
    require_command_output("copy testfile.dat dironly", copy_dir, ["1 File(s) copied."])
    copy_dir_type = send_command(sock, output_chunks, "type dironly\\testfile.dat")
    require_command_output("type dironly\\testfile.dat", copy_dir_type, ["Hello from TESTFILE.DAT! This is test data for LainDOS file I/O."])
    copy_no = send_command_answer(sock, output_chunks, "copy midemo\\subtest.dat copy1.dat", "Overwrite", "n")
    require_command_output("copy midemo\\subtest.dat copy1.dat", copy_no, ["File not copied."])
    copy_no_type = send_command(sock, output_chunks, "type copy1.dat")
    require_command_output("type copy1.dat", copy_no_type, ["Hello from TESTFILE.DAT! This is test data for LainDOS file I/O."], ["Hello from MIDEMO subdirectory!"])
    copy_yes = send_command(sock, output_chunks, "copy /y midemo\\subtest.dat copy1.dat")
    require_command_output("copy /y midemo\\subtest.dat copy1.dat", copy_yes, ["1 File(s) copied."])
    copy_yes_type = send_command(sock, output_chunks, "type copy1.dat")
    require_command_output("type copy1.dat", copy_yes_type, ["Hello from MIDEMO subdirectory!"])
    copy_prompt = send_command_answer(sock, output_chunks, "copy /y /-y testfile.dat copy1.dat", "Overwrite", "n")
    require_command_output("copy /y /-y testfile.dat copy1.dat", copy_prompt, ["File not copied."])
    copy_prompt_type = send_command(sock, output_chunks, "type copy1.dat")
    require_command_output("type copy1.dat", copy_prompt_type, ["Hello from MIDEMO subdirectory!"], ["Hello from TESTFILE.DAT!"])

    del_setup = send_command(sock, output_chunks, "copy testfile.dat del1.dat")
    require_command_output("copy testfile.dat del1.dat", del_setup, ["1 File(s) copied."])
    send_command(sock, output_chunks, "del del1.dat")
    del_type = send_command(sock, output_chunks, "type del1.dat")
    require_command_output("type del1.dat", del_type, ["File not found"])
    erase_setup = send_command(sock, output_chunks, "copy testfile.dat del2.dat")
    require_command_output("copy testfile.dat del2.dat", erase_setup, ["1 File(s) copied."])
    send_command(sock, output_chunks, "erase del2.dat")
    erase_type = send_command(sock, output_chunks, "type del2.dat")
    require_command_output("type del2.dat", erase_type, ["File not found"])
    del_prompt_setup = send_command(sock, output_chunks, "copy testfile.dat delp.dat")
    require_command_output("copy testfile.dat delp.dat", del_prompt_setup, ["1 File(s) copied."])
    del_prompt_no = send_command_answer(sock, output_chunks, "del /p delp.dat", "Delete", "n")
    require_command_output("del /p delp.dat", del_prompt_no, ["File not deleted."])
    del_prompt_no_type = send_command(sock, output_chunks, "type delp.dat")
    require_command_output("type delp.dat", del_prompt_no_type, ["Hello from TESTFILE.DAT!"])
    send_command_answer(sock, output_chunks, "del /p delp.dat", "Delete", "y")
    del_prompt_yes_type = send_command(sock, output_chunks, "type delp.dat")
    require_command_output("type delp.dat", del_prompt_yes_type, ["File not found"])
    del_no_arg = send_command(sock, output_chunks, "del")
    require_command_output("del", del_no_arg, ["Missing argument"])
    del_missing = send_command(sock, output_chunks, "del missing.dat")
    require_command_output("del missing.dat", del_missing, ["File error"])
    more_file = send_command(sock, output_chunks, "more testfile.dat")
    require_command_output("more testfile.dat", more_file, ["Hello from TESTFILE.DAT!"])
    more_missing = send_command(sock, output_chunks, "more missing.txt")
    require_command_output("more missing.txt", more_missing, ["File not found"])
    long_name = "q" * 62
    long_cmd = send_command(sock, output_chunks, long_name)
    require_command_output(long_name, long_cmd, ["Bad command or file name"])
    after_long = send_command(sock, output_chunks, "ver")
    require_command_output("ver", after_long, ["LainDOS"])
    del_wild_setup = send_command(sock, output_chunks, "copy testfile.dat wild.dat")
    require_command_output("copy testfile.dat wild.dat", del_wild_setup, ["1 File(s) copied."])
    del_wild = send_command(sock, output_chunks, "del wild*.dat")
    del_wild_type = send_command(sock, output_chunks, "type wild.dat")
    require_command_output("type wild.dat", del_wild_type, ["File not found"])
    del_wild_missing = send_command(sock, output_chunks, "del wild*.dat")
    require_command_output("del wild*.dat", del_wild_missing, ["File not found"])

    ren_setup = send_command(sock, output_chunks, "copy testfile.dat renold.dat")
    require_command_output("copy testfile.dat renold.dat", ren_setup, ["1 File(s) copied."])
    send_command(sock, output_chunks, "ren renold.dat rennew.dat")
    ren_old_type = send_command(sock, output_chunks, "type renold.dat")
    require_command_output("type renold.dat", ren_old_type, ["File not found"])
    ren_new_type = send_command(sock, output_chunks, "type rennew.dat")
    require_command_output("type rennew.dat", ren_new_type, ["Hello from TESTFILE.DAT!"])
    rename_setup = send_command(sock, output_chunks, "copy testfile.dat rename1.dat")
    require_command_output("copy testfile.dat rename1.dat", rename_setup, ["1 File(s) copied."])
    send_command(sock, output_chunks, "rename rename1.dat rename2.dat")
    rename_old_type = send_command(sock, output_chunks, "type rename1.dat")
    require_command_output("type rename1.dat", rename_old_type, ["File not found"])
    rename_new_type = send_command(sock, output_chunks, "type rename2.dat")
    require_command_output("type rename2.dat", rename_new_type, ["Hello from TESTFILE.DAT!"])
    ren_path_setup = send_command(sock, output_chunks, "copy testfile.dat renpath.dat")
    require_command_output("copy testfile.dat renpath.dat", ren_path_setup, ["1 File(s) copied."])
    ren_path = send_command(sock, output_chunks, "ren renpath.dat dironly\\renpath.dat")
    require_command_output("ren renpath.dat dironly\\renpath.dat", ren_path, ["Invalid destination"])
    ren_path_old_type = send_command(sock, output_chunks, "type renpath.dat")
    require_command_output("type renpath.dat", ren_path_old_type, ["Hello from TESTFILE.DAT!"])
    ren_path_new_type = send_command(sock, output_chunks, "type dironly\\renpath.dat")
    require_command_output("type dironly\\renpath.dat", ren_path_new_type, ["File not found"])
    ren_no_arg = send_command(sock, output_chunks, "ren")
    require_command_output("ren", ren_no_arg, ["Missing argument"])
    ren_one_arg = send_command(sock, output_chunks, "ren rennew.dat")
    require_command_output("ren rennew.dat", ren_one_arg, ["Missing argument"])
    ren_too_many = send_command(sock, output_chunks, "ren rennew.dat two.dat three.dat")
    require_command_output("ren rennew.dat two.dat three.dat", ren_too_many, ["Too many arguments"])
    ren_wild_src = send_command(sock, output_chunks, "ren ren*.dat renwild.dat")
    require_command_output("ren ren*.dat renwild.dat", ren_wild_src, ["Wildcard not supported"])
    ren_wild_dst = send_command(sock, output_chunks, "ren rennew.dat *.bak")
    require_command_output("ren rennew.dat *.bak", ren_wild_dst, ["Wildcard not supported"])
    ren_still_type = send_command(sock, output_chunks, "type rennew.dat")
    require_command_output("type rennew.dat", ren_still_type, ["Hello from TESTFILE.DAT!"])

    target_prompt = prompt_count(output_chunks) + 1
    send_text(sock, "extkey")
    send_monitor_key(sock, "ret")
    if not wait_for_output(output_chunks, "READY: EXTKEY", timeout=15, stop_markers=()):
        raise TimeoutError("timed out waiting for 'READY: EXTKEY'")
    send_monitor_key(sock, "f5")
    wait_for_prompt_count(output_chunks, target_prompt, context="prompt after EXTKEY")

    for command in [
        "timetest",
        "time",
        "testbat",
        "exemax",
        "memreg",
        "packseg",
        "hello",
        "helloexe",
        "exectest",
        "psptest",
        "mem",
        "free",
        "md shdir",
        "mkdir shalias",
        "dir",
        "cd..",
        "chdir shdir",
        "cd\\",
        "chdir shdir",
        "cd..",
        "rmdir shdir",
        "rd shalias",
        "cd shdir",
        "cd midemo",
        "dir",
        "type subtest.dat",
        "helloexe",
        "cd ..",
        "type testfile.dat",
        "nope",
    ]:
        send_command(sock, output_chunks, command)
    send_text(sock, "exit")
    send_monitor_key(sock, "ret")
    sock.close()


def run_qemu():
    try:
        os.unlink(MONITOR)
    except FileNotFoundError:
        pass
    proc, stdout_chunks, stderr_chunks, threads = start_qemu([
        QEMU,
        "-drive", f"file={IMG},format=raw,if=floppy",
        "-boot", "order=a",
        "-serial", "stdio",
        "-monitor", f"unix:{MONITOR},server,nowait",
        "-nographic",
    ])
    try:
        if not wait_for_output(stdout_chunks, "A:\\>", timeout=8, stop_markers=()):
            raise TimeoutError("timed out waiting for 'A:\\>'")
        send_keys(stdout_chunks)
    except Exception:
        proc.kill()
        proc.wait()
        for thread in threads:
            thread.join(timeout=1)
        raise
    output, _ = finish_qemu(proc, stdout_chunks, stderr_chunks, threads, timeout=8, stop_markers=("HALT", "Program exited, code=00"))
    return output


def main():
    build_image()
    output = run_qemu()
    failed = False
    build_id = build_shell_com.git_build_id()
    for marker in [
        f"LainDOS Shell {build_id}",
        "A:\\>",
        "SHELL    COM",
        "HELLO.COM",
        "HELLOEXE EXE",
        "Volume in drive A has no label",
        "Directory of A:\\",
        "HELLO    COM",
        "<DIR>",
        "File(s)",
        "Dir(s)",
        "bytes free",
        "Press any key to continue . . .",
        "DIRONLY",
        "Hello from TESTFILE.DAT! This is test data for LainDOS file I/O.",
        "interactive echo",
        "PASS: HELLO.EXE",
        "EXECTEST COM",
        "PASS: EXECTEST",
        "PASS: PSP",
        "PASS: KEY",
        "PASS: EXTKEY",
        "PASS: TIME",
        "Current time:",
        "PASS: ARGTEST",
        "PASS: ARGEXE",
        "PASS: EXEMAX",
        "PASS: MEMREG",
        "PASS: PACKSEG",
        "Memory type        Total       Used    Free",
        "Extended (XMS)",
        "Total memory",
        "Total Expanded (EMS)",
        "Largest executable program size",
        "SHALIAS",
        "A:\\SHDIR>",
        "Path not found",
        "A:\\MIDEMO>",
        "SUBTEST  DAT",
        "Hello from MIDEMO subdirectory!",
        "Bad command or file name",
        "Program exited, code=00",
    ]:
        if marker in output:
            print(f"  PASS: found '{marker}'")
        else:
            print(f"  FAIL: missing '{marker}'")
            failed = True
    if output.count("PASS: HELLO.COM") >= 4:
        print("  PASS: found at least four HELLO.COM runs")
    else:
        print("  FAIL: expected at least four HELLO.COM runs")
        failed = True
    if output.count("Hello from TESTFILE.DAT! This is test data for LainDOS file I/O.") >= 2:
        print("  PASS: found root TYPE before and after CD ..")
    else:
        print("  FAIL: expected root TYPE before and after CD ..")
        failed = True
    if output.count("Path not found") == 1:
        print("  PASS: CD .. at root did not error")
    else:
        print("  FAIL: expected exactly one Path not found")
        failed = True
    if output.count("Bad command or file name") == 2:
        print("  PASS: only deliberate bad commands failed")
    else:
        print("  FAIL: expected exactly two bad commands")
        failed = True
    for pattern, description in [
        (r"File\(s\)\s+\d+ bytes \(\d+\.\d+ (?:KB|MB|GB)\)", "human-readable DIR used space"),
        (r"Dir\(s\)\s+\d+ bytes free \(\d+\.\d+ (?:KB|MB|GB)\)", "human-readable DIR free space"),
    ]:
        if re.search(pattern, output):
            print(f"  PASS: found {description}")
        else:
            print(f"  FAIL: missing {description}")
            failed = True
    for marker in ["FAIL:", "EXC ", "INT 21h AH=", "Invalid MCB chain"]:
        if marker in output:
            print(f"  FAIL: unexpected '{marker}'")
            failed = True
    if failed:
        print("\n--- QEMU serial output ---")
        print(output)
        print("--- end ---")
        sys.exit(1)
    print("\nShell test passed.")


if __name__ == "__main__":
    main()
