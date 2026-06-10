#!/usr/bin/env python3
"""Pure-Python checks for mkimage capacity guards (no QEMU)."""
import importlib.util
import sys

spec = importlib.util.spec_from_file_location("mkimage", "scripts/mkimage.py")
mkimage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mkimage)


def expect_raises(fn, what):
    try:
        fn()
    except RuntimeError:
        print(f"  PASS: {what} raised")
        return True
    print(f"  FAIL: {what} did not raise")
    return False


def main():
    ok = True

    img = mkimage.Fat12Image()
    limit = img.max_cluster()
    img.next_cluster = limit
    if img.alloc_cluster() == limit:
        print("  PASS: last valid cluster is allocatable")
    else:
        print("  FAIL: last valid cluster rejected")
        ok = False
    ok = expect_raises(img.alloc_cluster, "one-past-last cluster") and ok

    img2 = mkimage.Fat12Image()
    img2.next_cluster = img2.max_cluster() - 1
    ok = expect_raises(lambda: img2.alloc_clusters(3),
                       "multi-cluster overflow") and ok

    img3 = mkimage.Fat12Image()
    for i in range(mkimage.ROOT_ENT_CNT):
        img3.add_root_entry(bytearray(32))
    print(f"  PASS: filled {mkimage.ROOT_ENT_CNT} root entries")
    ok = expect_raises(lambda: img3.add_root_entry(bytearray(32)),
                       "root directory overflow") and ok

    if not ok:
        sys.exit(1)
    print("\nmkimage capacity test passed.")


if __name__ == "__main__":
    main()
