#!/usr/bin/env python3
"""Retag a static library's arm64 iOS objects as iOS Simulator objects
(LC_BUILD_VERSION platform 2 -> 7), in place. Used by tools/build-ios.sh sim.
"""
import struct,sys
p=sys.argv[1]; b=bytearray(open(p,'rb').read())
assert b[:8]==b'!<arch>\n'
i=8; n=0
while i<len(b):
    h=b[i:i+60]; name=h[:16].decode().strip(); size=int(h[48:58]); d=i+60; body=d; blen=size
    if name.startswith('#1/'):
        l=int(name[3:]); body=d+l; blen=size-l
    if struct.unpack_from('<I',b,body)[0]==0xfeedfacf:
        ncmds=struct.unpack_from('<I',b,body+16)[0]; o=body+32
        for _ in range(ncmds):
            cmd,cs=struct.unpack_from('<II',b,o)
            if cmd==0x32 and struct.unpack_from('<I',b,o+8)[0]==2:
                struct.pack_into('<I',b,o+8,7); n+=1
            o+=cs
    i=d+size+(size&1)
open(p,'wb').write(b); print('patched',n)
