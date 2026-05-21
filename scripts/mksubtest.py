#!/usr/bin/env python3
import sys
data = b"Hello from MIDEMO subdirectory!\n"
with open(sys.argv[1], 'wb') as f:
    f.write(data)
