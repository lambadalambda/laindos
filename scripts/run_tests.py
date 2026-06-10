#!/usr/bin/env python3
import argparse
import os
import shutil
import signal
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from pathlib import Path


DEFAULT_TESTS = [
    "scripts/test_autoexec.py",
    "scripts/test_boot.py",
    "scripts/test_boot_chain_bounds.py",
    "scripts/test_bpb_invalid.py",
    "scripts/test_cd_bios.py",
    "scripts/test_cd_file.py",
    "scripts/test_cd_subdir.py",
    "scripts/test_cd_find.py",
    "scripts/test_cd_mscdex.py",
    "scripts/test_cd_exec.py",
    "scripts/test_highmcb.py",
    "scripts/test_stratapi.py",
    "scripts/test_memrelease.py",
    "scripts/test_memfail.py",
    "scripts/test_write.py",
    "scripts/test_rwedge.py",
    "scripts/test_bigreloc.py",
    "scripts/test_keyboard.py",
    "scripts/test_flushread.py",
    "scripts/test_stateapi.py",
    "scripts/test_fcbfind.py",
    "scripts/test_versionapi.py",
    "scripts/test_datetime.py",
    "scripts/test_timeoffset.py",
    "scripts/test_mouse.py",
    "scripts/test_mousecb.py",
    "scripts/test_mouseratio.py",
    "scripts/test_xms.py",
    "scripts/test_ems.py",
    "scripts/test_overlay.py",
    "scripts/test_retcode.py",
    "scripts/test_execparam.py",
    "scripts/test_exectail.py",
    "scripts/test_spawn.py",
    "scripts/test_tsr.py",
    "scripts/test_jft.py",
    "scripts/test_shell.py",
    "scripts/test_shell_batch_builtins.py",
    "scripts/test_console.py",
    "scripts/test_devnames.py",
    "scripts/test_diskfree.py",
    "scripts/test_drivedata.py",
    "scripts/test_dup.py",
    "scripts/test_commit.py",
    "scripts/test_dbcs.py",
    "scripts/test_compatapi.py",
    "scripts/test_createapi.py",
    "scripts/test_handlecnt.py",
    "scripts/test_handleleak.py",
    "scripts/test_drive.py",
    "scripts/test_multidrive.py",
    "scripts/test_multidrive_shell.py",
    "scripts/test_diredge.py",
    "scripts/test_drivepath.py",
    "scripts/test_dosstruct.py",
    "scripts/test_parsefcb.py",
    "scripts/test_ioctlstat.py",
    "scripts/test_ioctlext.py",
    "scripts/test_irqmask.py",
    "scripts/test_fat16.py",
    "scripts/test_fat16_bounds.py",
    "scripts/test_partitioned_fat16.py",
    "scripts/test_fat16_large.py",
    "scripts/test_fat16_seek.py",
    "scripts/test_highdir.py",
    "scripts/test_badfat.py",
    "scripts/test_free.py",
    "scripts/test_dirextfail.py",
    "scripts/test_dirextrollback.py",
    "scripts/test_envmcb.py",
    "scripts/test_execenv.py",
    "scripts/test_envoflow.py",
    "scripts/test_mcbcoex.py",
    "scripts/test_envpath.py",
    "scripts/test_pathcanon.py",
    "scripts/test_findedge.py",
    "scripts/test_findattr.py",
    "scripts/test_attrapi.py",
    "scripts/test_findnext.py",
    "scripts/test_findtime.py",
    "scripts/test_readcache.py",
    "scripts/test_seekedge.py",
    "scripts/test_regpres.py",
    "scripts/test_savewrite.py",
    "scripts/test_rnguard.py",
    "scripts/test_termflush.py",
    "scripts/test_dirmut.py",
    "scripts/test_readwrap.py",
    "scripts/test_pathbuf.py",
    "scripts/test_execseg.py",
    "scripts/test_linebuf.py",
    "scripts/test_ffroot.py",
    "scripts/test_findstar.py",
    "scripts/test_int24h.py",
    "scripts/test_ffname.py",
    "scripts/test_indos.py",
    "scripts/test_mouseindos.py",
    "scripts/test_hma.py",
    "scripts/test_fat16_label.py",
    "scripts/test_openattr.py",
    "scripts/test_vecrest.py",
    "scripts/test_stdread.py",
    "scripts/test_ovlbig.py",
    "scripts/test_name83.py",
    "scripts/test_aliasdrv.py",
    "scripts/test_loopchn.py",
    "scripts/test_badname.py",
    "scripts/test_cdmut.py",
    "scripts/test_execleak.py",
    "scripts/test_tsrenv.py",
    "scripts/test_exehdr.py",
    "scripts/test_envbig.py",
    "scripts/test_trunc0.py",
    "scripts/test_badclus.py",
    "scripts/test_colonpth.py",
    "scripts/test_mouseeoi.py",
    "scripts/test_mouserst.py",
    "scripts/test_clock.py",
    "scripts/test_ctrlc.py",
    "scripts/test_conread.py",
    "scripts/test_cddots.py",
    "scripts/test_stacktight.py",
    "scripts/test_ioctl2.py",
]
BOOT_TESTS = {"test_boot.py"}
TIMEOUT_EXIT_CODE = 124


@dataclass
class TestResult:
    index: int
    test: str
    label: str
    returncode: int
    elapsed: float
    stdout: str
    stderr: str


def repo_root():
    return Path(__file__).resolve().parent.parent


def default_jobs():
    return min(4, os.cpu_count() or 1)


def default_build_root():
    return repo_root() / "build" / "tests" / f"run-{os.getpid()}"


def is_relative_to(path, parent):
    try:
        path.relative_to(parent)
        return True
    except ValueError:
        return False


def cleanup_build_root(root, build_root, keep_build):
    if keep_build:
        return
    safe_parent = (root / "build" / "tests").resolve()
    resolved = build_root.resolve()
    if not is_relative_to(resolved, safe_parent):
        print(f"NOTE: keeping build root outside {safe_parent}: {resolved}")
        return
    shutil.rmtree(resolved, ignore_errors=True)


def build_env(build_root, index, test):
    env = os.environ.copy()
    if Path(test).name in BOOT_TESTS:
        return env
    test_dir = build_root / f"{index:02d}-{Path(test).stem}"
    shutil.rmtree(test_dir, ignore_errors=True)
    test_dir.mkdir(parents=True, exist_ok=True)
    env["LAINDOS_TEST_BUILD_DIR"] = str(test_dir)
    return env


def stop_process_group(proc, sig):
    try:
        os.killpg(proc.pid, sig)
    except ProcessLookupError:
        return


def run_test_process(root, env, test, timeout):
    proc = subprocess.Popen(
        [sys.executable, test],
        cwd=root,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
        start_new_session=True,
    )
    try:
        stdout, stderr = proc.communicate(timeout=timeout)
        return proc.returncode, stdout, stderr
    except subprocess.TimeoutExpired:
        stop_process_group(proc, signal.SIGTERM)
        try:
            stdout, stderr = proc.communicate(timeout=3)
        except subprocess.TimeoutExpired:
            stop_process_group(proc, signal.SIGKILL)
            stdout, stderr = proc.communicate()
        stderr += f"FAIL: {test} timed out after {timeout}s\n"
        return TIMEOUT_EXIT_CODE, stdout, stderr


def run_one(root, build_root, index, test, timeout):
    label = f"{Path(sys.executable).name} {test}"
    env = build_env(build_root, index, test)
    start = time.monotonic()
    returncode, stdout, stderr = run_test_process(root, env, test, timeout)
    elapsed = time.monotonic() - start
    return TestResult(index, test, label, returncode, elapsed, stdout, stderr)


def print_result(result):
    print(f"=== [{result.index:02d}] {result.label} ===")
    if result.stdout:
        print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="")
    print(f"TIME: {result.label} {result.elapsed:.2f}s")
    if result.returncode != 0:
        print(f"FAIL: {result.label} exited {result.returncode}")


def parse_args():
    parser = argparse.ArgumentParser(description="Run LainDOS tests, optionally in parallel.")
    parser.add_argument("tests", nargs="*", help="test scripts to run; defaults to the make test suite")
    parser.add_argument("-j", "--jobs", type=int, default=default_jobs(), help="parallel jobs to run")
    parser.add_argument("--timeout", type=int, default=300, help="outer timeout per test in seconds")
    parser.add_argument(
        "--build-root",
        default=str(default_build_root()),
        help="directory for per-test build outputs; successful runs under build/tests are removed unless --keep-build is set",
    )
    parser.add_argument("--keep-build", action="store_true", help="keep per-run build outputs after a successful run")
    return parser.parse_args()


def main():
    args = parse_args()
    if args.jobs < 1:
        print("FAIL: --jobs must be at least 1", file=sys.stderr)
        return 2
    if args.timeout < 1:
        print("FAIL: --timeout must be at least 1", file=sys.stderr)
        return 2

    root = repo_root()
    build_root = Path(args.build_root)
    if not build_root.is_absolute():
        build_root = root / build_root
    tests = args.tests or DEFAULT_TESTS
    started = time.monotonic()
    failures = []

    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        futures = [pool.submit(run_one, root, build_root, index, test, args.timeout) for index, test in enumerate(tests, start=1)]
        for future in as_completed(futures):
            result = future.result()
            print_result(result)
            if result.returncode != 0:
                failures.append(result)

    elapsed = time.monotonic() - started
    passed = len(tests) - len(failures)
    print(f"\nSUMMARY: {passed}/{len(tests)} tests passed in {elapsed:.2f}s with -j {args.jobs}")
    if failures:
        print("FAILED:")
        for result in sorted(failures, key=lambda item: item.index):
            print(f"  {result.label}")
        return 1
    cleanup_build_root(root, build_root, args.keep_build)
    return 0


if __name__ == "__main__":
    sys.exit(main())
