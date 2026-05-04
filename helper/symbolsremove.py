#!/usr/bin/env python3
# Remove a named xkb_symbols block from an XKB symbols file (e.g. symbols/us, symbols/ru)
# Usage: symbolsremove.py <symbols_file> <block_name>
# Example: symbolsremove.py /usr/share/X11/xkb/symbols/us typo-birman-en

import sys

if len(sys.argv) != 3:
    print(f"Usage: {sys.argv[0]} <symbols_file> <block_name>", file=sys.stderr)
    sys.exit(1)

symbols_file, block_name = sys.argv[1], sys.argv[2]
marker = f'xkb_symbols "{block_name}"'

with open(symbols_file) as f:
    lines = f.readlines()

result: list[str] = []
in_block = False
depth = 0

for line in lines:
    if not in_block:
        if marker in line:
            # Remove the "partial default alphanumeric_keys" header line
            if result and result[-1].strip() == "partial default alphanumeric_keys":
                result.pop()
            # Remove trailing blank lines before the block
            while result and result[-1].strip() == "":
                result.pop()
            in_block = True
            depth = 0
        else:
            result.append(line)
    else:
        depth += line.count("{") - line.count("}")
        if depth <= 0 and "}" in line:
            in_block = False

with open(symbols_file, "w") as f:
    f.writelines(result)

print(f"Removed block '{block_name}' from {symbols_file}")
