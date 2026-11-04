#!/usr/bin/env python3
"""Checks that every 64-bit native library in an APK or AAB loads on 16 KB page phones.

Google Play requires it for apps that target Android 15 or later: each PT_LOAD segment of each
arm64-v8a and x86_64 library must be aligned to at least 16 KB. Libraries are read straight
from the archive (lib/<abi>/ in an APK, base/lib/<abi>/ in an AAB).

    python3 tools/bikemodo_check_16kb.py app.aab
Exits 1 and lists the libraries that are not aligned.
"""
import struct
import sys
import zipfile

PAGE = 16384
PT_LOAD = 1
ABIS = ("arm64-v8a", "x86_64")


def load_alignments(data):
    """The p_align of each PT_LOAD segment of a 64-bit little-endian ELF file."""
    if data[:4] != b"\x7fELF" or data[4] != 2 or data[5] != 1:
        return None
    phoff = struct.unpack_from("<Q", data, 0x20)[0]
    phentsize, phnum = struct.unpack_from("<HH", data, 0x36)
    aligns = []
    for i in range(phnum):
        base = phoff + i * phentsize
        p_type = struct.unpack_from("<I", data, base)[0]
        if p_type == PT_LOAD:
            aligns.append(struct.unpack_from("<Q", data, base + 0x30)[0])
    return aligns


def abi_of(name):
    """lib/arm64-v8a/libx.so or base/lib/arm64-v8a/libx.so -> arm64-v8a"""
    parts = name.split("/")
    if len(parts) >= 3 and parts[-3] == "lib":
        return parts[-2]
    return ""


def main(path):
    checked = 0
    bad = []
    with zipfile.ZipFile(path) as archive:
        for name in archive.namelist():
            if not name.endswith(".so") or abi_of(name) not in ABIS:
                continue
            aligns = load_alignments(archive.read(name))
            if aligns is None:
                bad.append((name, "not a 64-bit ELF library"))
                continue
            checked += 1
            small = [a for a in aligns if a < PAGE]
            if small:
                bad.append((name, "segments aligned to %d" % min(small)))
    for name, why in bad:
        print("NOT 16 KB: %s (%s)" % (name, why))
    print("%d libraries checked, %d not aligned to 16 KB" % (checked, len(bad)))
    if checked == 0:
        print("no 64-bit libraries found in " + path)
        return 1
    return 1 if bad else 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("usage: bikemodo_check_16kb.py <app.apk|app.aab>")
        sys.exit(2)
    sys.exit(main(sys.argv[1]))
