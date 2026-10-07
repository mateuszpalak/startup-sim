#!/usr/bin/env python3
"""Retag a static library's arm64 iOS objects as iOS Simulator objects
(LC_BUILD_VERSION platform 2 -> 7), in place. Used by tools/build-ios.sh sim.
"""
import struct
import sys

MH_MAGIC_64 = 0xFEEDFACF
LC_BUILD_VERSION = 0x32
PLATFORM_IOS = 2
PLATFORM_IOS_SIMULATOR = 7


def retag(data):
    """Patches every arm64 object in the ar archive; returns how many."""
    assert data[:8] == b"!<arch>\n", "not an ar archive"
    i = 8
    patched = 0
    while i < len(data):
        header = data[i:i + 60]
        name = header[:16].decode().strip()
        size = int(header[48:58])
        start = i + 60
        body = start
        if name.startswith("#1/"):  # BSD long name right after the header
            body += int(name[3:])
        if struct.unpack_from("<I", data, body)[0] == MH_MAGIC_64:
            ncmds = struct.unpack_from("<I", data, body + 16)[0]
            o = body + 32
            for _ in range(ncmds):
                cmd, cmdsize = struct.unpack_from("<II", data, o)
                if cmd == LC_BUILD_VERSION and struct.unpack_from("<I", data, o + 8)[0] == PLATFORM_IOS:
                    struct.pack_into("<I", data, o + 8, PLATFORM_IOS_SIMULATOR)
                    patched += 1
                o += cmdsize
        i = start + size + (size & 1)
    return patched


def main():
    path = sys.argv[1]
    with open(path, "rb") as fh:
        data = bytearray(fh.read())
    n = retag(data)
    with open(path, "wb") as fh:
        fh.write(data)
    print("patched", n)


if __name__ == "__main__":
    main()
