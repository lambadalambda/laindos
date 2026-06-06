#!/usr/bin/env python3
import os
import re
import socket
import subprocess
import sys
import time
from testlib import build_dir, finish_qemu, start_qemu, wait_for_output

QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "shelltest.img")
KERNEL = os.path.join(BUILDDIR, "shelltest_kernel.bin")
MONITOR = os.path.join(BUILDDIR, "shelltest.sock")
KEY_DELAY = 0.02
KEY_HOLD_MS = 10
PROMPT_RE = re.compile(rb"A:\\[^>\r\n]*>")
KEYMAP = {" ": "spc", "\\": "backslash", ".": "dot", "/": "slash", "-": "minus", "_": "shift-minus", ":": "shift-semicolon", "*": "shift-8"}


def run(cmd):
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.stdout:
        print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="", file=sys.stderr)
    if result.returncode != 0:
        sys.exit(result.returncode)


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    run(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", os.path.join(BUILDDIR, "boot.bin")])
    run([
        "nasm", '-DBOOT_FILE="SHELL   COM"', "-f", "bin", "src/kernel.asm",
        "-o", KERNEL,
    ])
    run(["nasm", "-f", "bin", "programs/shell.asm", "-o", os.path.join(BUILDDIR, "shell.com")])
    run(["nasm", "-f", "bin", "tests/programs/hello.asm", "-o", os.path.join(BUILDDIR, "hello.com")])
    run(["nasm", "-f", "bin", "tests/programs/helloexe.asm", "-o", os.path.join(BUILDDIR, "helloexe.exe")])
    run(["nasm", "-f", "bin", "tests/programs/exectest.asm", "-o", os.path.join(BUILDDIR, "exectest.com")])
    run(["nasm", "-f", "bin", "tests/programs/psptest.asm", "-o", os.path.join(BUILDDIR, "psptest.com")])
    run(["nasm", "-f", "bin", "tests/programs/pspchild.asm", "-o", os.path.join(BUILDDIR, "pspchild.com")])
    run(["nasm", "-f", "bin", "tests/programs/keytest.asm", "-o", os.path.join(BUILDDIR, "keytest.com")])
    run(["nasm", "-f", "bin", "tests/programs/extkey.asm", "-o", os.path.join(BUILDDIR, "extkey.com")])
    run(["nasm", "-f", "bin", "tests/programs/timetest.asm", "-o", os.path.join(BUILDDIR, "timetest.com")])
    run(["nasm", "-f", "bin", "tests/programs/argtest.asm", "-o", os.path.join(BUILDDIR, "argtest.com")])
    run(["nasm", "-f", "bin", "tests/programs/argexe.asm", "-o", os.path.join(BUILDDIR, "argexe.exe")])
    run(["nasm", "-f", "bin", "tests/programs/exemax.asm", "-o", os.path.join(BUILDDIR, "exemax.exe")])
    run(["nasm", "-f", "bin", "tests/programs/memreg.asm", "-o", os.path.join(BUILDDIR, "memreg.com")])
    run(["nasm", "-f", "bin", "tests/programs/packseg.asm", "-o", os.path.join(BUILDDIR, "packseg.exe")])
    run(["nasm", "-f", "bin", "programs/free.asm", "-o", os.path.join(BUILDDIR, "free.com")])
    run(["nasm", "-f", "bin", "programs/free.asm", "-o", os.path.join(BUILDDIR, "mem.com")])
    run(["python3", "scripts/mktestfile.py", os.path.join(BUILDDIR, "testfile.dat")])
    run(["python3", "scripts/mksubtest.py", os.path.join(BUILDDIR, "subtest.dat")])
    with open(os.path.join(BUILDDIR, "testbat.bat"), "wb") as f:
        f.write(b"Echo off\r\nargtest gdemo /3\r\nargexe gdemo /3\r\nEcho on\r\n")
    run([
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
    for command in ["ver", "cls", "dir", "type testfile.dat", "echo interactive echo", "rem interactive comment", "hello", "keytest"]:
        send_command(sock, output_chunks, command)
    send_paged_dir(sock, output_chunks, "dir /p")
    send_paged_dir(sock, output_chunks, "dir/p")

    dir_midemo = send_command(sock, output_chunks, "dir midemo")
    require_command_output("dir midemo", dir_midemo, ["Directory of A:\\MIDEMO", "SUBTEST  DAT"])
    dir_midemo_dat = send_command(sock, output_chunks, "dir midemo\\*.dat")
    require_command_output("dir midemo\\*.dat", dir_midemo_dat, ["SUBTEST  DAT"], ["HELLOEXE EXE"])
    dir_com = send_command(sock, output_chunks, "dir *.com")
    require_command_output("dir *.com", dir_com, ["SHELL    COM", "HELLO    COM"], ["HELLOEXE EXE"])
    dir_wide = send_command(sock, output_chunks, "dir /w")
    require_command_output("dir /w", dir_wide, ["SHELL.COM", "[DIRONLY]"])
    if not re.search(rb"SHELL\.COM[^\r\n]+HELLO\.COM", dir_wide):
        raise RuntimeError("'dir /w' did not print multiple file names on one row")

    copy_new = send_command(sock, output_chunks, "copy testfile.dat copy1.dat")
    require_command_output("copy testfile.dat copy1.dat", copy_new, ["1 File(s) copied."])
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

    target_prompt = prompt_count(output_chunks) + 1
    send_text(sock, "extkey")
    send_monitor_key(sock, "ret")
    if not wait_for_output(output_chunks, "READY: EXTKEY", timeout=15, stop_markers=()):
        raise TimeoutError("timed out waiting for 'READY: EXTKEY'")
    send_monitor_key(sock, "f5")
    wait_for_prompt_count(output_chunks, target_prompt, context="prompt after EXTKEY")

    for command in [
        "timetest",
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
    for marker in [
        "LainDOS Shell",
        "A:\\>",
        "SHELL    COM",
        "HELLO.COM",
        "HELLOEXE EXE",
        "Volume in drive A has no label",
        "Directory of A:\\",
        "HELLO    COM",
        "<DIR>",
        "File(s)",
        "bytes free",
        "Press any key to continue . . .",
        "DIRONLY",
        "Hello from TESTFILE.DAT! This is test data for LainDOS file I/O.",
        "INTERACTIVE ECHO",
        "PASS: HELLO.EXE",
        "EXECTEST COM",
        "PASS: EXECTEST",
        "PASS: PSP",
        "PASS: KEY",
        "PASS: EXTKEY",
        "PASS: TIME",
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
    if output.count("PASS: HELLO.COM") >= 3:
        print("  PASS: found three HELLO.COM runs")
    else:
        print("  FAIL: expected three HELLO.COM runs")
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
    if output.count("Bad command or file name") == 1:
        print("  PASS: only deliberate bad command failed")
    else:
        print("  FAIL: expected exactly one bad command")
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
