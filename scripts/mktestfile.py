#!/usr/bin/env python3
import sys
data = b"Hello from TESTFILE.DAT! This is test data for LainDOS file I/O.\n"
with open(sys.argv[1], 'wb') as f:
    f.write(data)
