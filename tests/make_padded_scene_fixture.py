#!/usr/bin/env python3
"""Create a >150 MiB, structurally valid scene GLB from a Creator .rmission.

Usage: python3 make_padded_scene_fixture.py /path/to/small.rmission /path/to/output.glb
The fixture deliberately pads an otherwise real exported scene's BIN buffer with
unused bytes. It exercises the package size path, not large-scene rendering or
physical Android memory performance. The output is about 160 MiB.
"""
import json
import struct
import sys

source, output = sys.argv[1:3]
with open(source, "rb") as f:
    h = f.read(12)
    if h[:8] != b"RMISSN04":
        raise SystemExit("Need a version 4 .rmission with an embedded scene")
    manifest_size = struct.unpack_from("<I", h, 8)[0]
    m = json.loads(f.read(manifest_size))
    scene = None
    for record in m["assets"]:
        data = f.read(record["length"])
        if record.get("category") == "scene":
            scene = data
    if scene is None:
        raise SystemExit("The package contains no exported scene")
magic, version, original_size = struct.unpack_from("<4sII", scene, 0)
assert magic == b"glTF" and version == 2 and original_size == len(scene)
json_len, kind = struct.unpack_from("<I4s", scene, 12)
assert kind == b"JSON"
doc = json.loads(scene[20:20 + json_len])
bin_off = 20 + json_len
bin_len, kind = struct.unpack_from("<I4s", scene, bin_off)
assert kind == b"BIN\0" and bin_off + 8 + bin_len == len(scene)
target_bin = 160 * 1024 * 1024
assert bin_len < target_bin and len(doc["buffers"]) == 1
doc["buffers"][0]["byteLength"] = target_bin
json_data = json.dumps(doc, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
json_data += b" " * ((-len(json_data)) % 4)
total = 12 + 8 + len(json_data) + 8 + target_bin
with open(output, "wb") as f:
    f.write(struct.pack("<4sII", b"glTF", 2, total))
    f.write(struct.pack("<I4s", len(json_data), b"JSON"))
    f.write(json_data)
    f.write(struct.pack("<I4s", target_bin, b"BIN\0"))
    f.write(scene[bin_off + 8:])
    # Sparse padding avoids spending time and memory allocating an unused BIN.
    f.seek(total - 1)
    f.write(b"\0")
print("Fixture GLB:", output, "size:", total, "bytes")
