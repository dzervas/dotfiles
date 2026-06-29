#!/usr/bin/env python3
"""
Parse an Unreal .pak footer + index to determine encryption/version and (optionally)
list asset paths. Useful to confirm a game's pak is unencrypted before attempting any
pak-based mod, and to enumerate asset paths without FModel.

Confirmed against RogueCore-Windows.pak: version 11, unencrypted index, Oodle, plaintext
Full Directory Index (~106k files). Other paks/versions may differ — this handles v11.

Magic = 0x5A6F12E1 (bytes E1 12 6F 5A). Footer is near the end of the file.

Usage:  python3 pak_footer.py /path/to/Game-Windows.pak [--list SUBSTR]
"""
import io
import struct
import sys


def parse(path, list_substr=None):
    f = open(path, "rb")
    f.seek(0, 2)
    size = f.tell()
    # Footer magic sits ~204 bytes from EOF for v11; scan a small window for it.
    f.seek(size - 204)
    foot = f.read(204)
    mp = foot.find(b"\xe1\x12\x6f\x5a")
    if mp < 0:
        print("magic not found in last 204 bytes; different pak version/layout")
        return
    base = size - 204 + mp
    f.seek(base)
    f.read(4)                                   # magic
    version = struct.unpack("<I", f.read(4))[0]
    index_off = struct.unpack("<q", f.read(8))[0]
    index_size = struct.unpack("<q", f.read(8))[0]
    f.read(20)                                   # index sha1
    enc_byte = f.read(1)                         # bEncryptedIndex
    encrypted = enc_byte != b"\x00"
    print(f"version={version}  index_off={hex(index_off)}  index_size={hex(index_size)}")
    print(f"bEncryptedIndex={enc_byte.hex()}  ({'ENCRYPTED' if encrypted else 'unencrypted'})")

    # Primary index (v10+): MountPoint, NumEntries, PathHashSeed, PathHashIndex block,
    # FullDirectoryIndex block, then encoded entries.
    f.seek(index_off)
    idx = f.read(index_size)
    b = io.BytesIO(idx)

    def fstr(buf):
        n = struct.unpack("<i", buf.read(4))[0]
        if n == 0:
            return ""
        if n < 0:
            return buf.read(-n * 2).decode("utf-16-le", "replace").rstrip("\x00")
        return buf.read(n).decode("utf-8", "replace").rstrip("\x00")

    mount = fstr(b)
    num = struct.unpack("<I", b.read(4))[0]
    print(f"mount={mount!r}  numEntries={num}")
    if enc_byte != b"\x00":
        print("index encrypted -> AES key required to read further")
        return

    b.read(8)                                   # PathHashSeed
    b.read(4); b.read(8); b.read(8); b.read(20) # PathHashIndex (present flag + off/size/sha)
    has_fdi = struct.unpack("<I", b.read(4))[0]
    fdi_off = struct.unpack("<q", b.read(8))[0]
    fdi_size = struct.unpack("<q", b.read(8))[0]
    if not has_fdi:
        print("no Full Directory Index")
        return

    # FDI is plaintext: numDirs, then per-dir: dirname, numFiles, per-file: filename + u32.
    f.seek(fdi_off)
    d = io.BytesIO(f.read(fdi_size))

    def rstr(buf):
        n = struct.unpack("<i", buf.read(4))[0]
        if n == 0:
            return ""
        if n < 0:
            return buf.read(-n * 2).decode("utf-16-le", "replace").rstrip("\x00")
        return buf.read(n).decode("utf-8", "replace").rstrip("\x00")

    ndirs = struct.unpack("<I", d.read(4))[0]
    paths = []
    for _ in range(ndirs):
        dn = rstr(d)
        nf = struct.unpack("<I", d.read(4))[0]
        for _ in range(nf):
            fn = rstr(d)
            d.read(4)
            paths.append(dn + fn)
    print(f"numDirs={ndirs}  totalPaths={len(paths)}")
    if list_substr:
        hits = sorted(set(p for p in paths if list_substr.lower() in p.lower()))
        print(f"-- paths containing {list_substr!r}: {len(hits)} --")
        for h in hits[:80]:
            print("  ", h)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    substr = None
    if "--list" in sys.argv:
        i = sys.argv.index("--list")
        substr = sys.argv[i + 1] if i + 1 < len(sys.argv) else ""
    parse(sys.argv[1], substr)
