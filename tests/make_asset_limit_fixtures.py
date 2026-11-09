#!/usr/bin/env python3
"""Make sparse GLB fixtures at/above the 150 MiB limit for regression tests.

These contain a tiny real triangle or animation and unused binary padding;
they exercise file-size handling, not 150 MiB of real geometry or texture data.
Usage: python3 tests/make_asset_limit_fixtures.py OUTPUT_DIRECTORY
"""
from pathlib import Path
import json
import struct
import sys

out = Path(sys.argv[1])
out.mkdir(parents=True, exist_ok=True)


def write_glb(path, kind, total):
    if kind == "model":
        binary = struct.pack("<9f3H", 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 1, 2)
        doc = {
            "asset": {"version": "2.0"},
            "scene": 0, "scenes": [{"nodes": [0]}],
            "nodes": [{"name": "Triangle", "mesh": 0}],
            "meshes": [{"primitives": [{"attributes": {"POSITION": 0}, "indices": 1}]}],
            "bufferViews": [{"buffer": 0, "byteOffset": 0, "byteLength": 36},
                            {"buffer": 0, "byteOffset": 36, "byteLength": 6}],
            "accessors": [{"bufferView": 0, "componentType": 5126, "count": 3,
                           "type": "VEC3", "min": [0, 0, 0], "max": [1, 1, 0]},
                          {"bufferView": 1, "componentType": 5123, "count": 3,
                           "type": "SCALAR"}],
            "buffers": [{"byteLength": total}],
        }
    else:
        binary = struct.pack("<8f", 0, 1, 0, 0, 0, 1, 0, 0)
        doc = {
            "asset": {"version": "2.0"},
            "scene": 0, "scenes": [{"nodes": [0]}],
            "nodes": [{"name": "AnimatedNode"}],
            "animations": [{"name": "Move",
                "samplers": [{"input": 0, "output": 1, "interpolation": "LINEAR"}],
                "channels": [{"sampler": 0, "target": {"node": 0, "path": "translation"}}]}],
            "bufferViews": [{"buffer": 0, "byteOffset": 0, "byteLength": 8},
                            {"buffer": 0, "byteOffset": 8, "byteLength": 24}],
            "accessors": [{"bufferView": 0, "componentType": 5126, "count": 2,
                           "type": "SCALAR", "min": [0], "max": [1]},
                          {"bufferView": 1, "componentType": 5126, "count": 2,
                           "type": "VEC3"}],
            "buffers": [{"byteLength": total}],
        }
    for _ in range(5):
        js = json.dumps(doc, separators=(",", ":")).encode("utf-8")
        js += b" " * (-len(js) % 4)
        bin_size = total - (12 + 8 + len(js) + 8)
        if doc["buffers"][0]["byteLength"] == bin_size:
            break
        doc["buffers"][0]["byteLength"] = bin_size
    else:
        raise RuntimeError("Could not stabilize GLB length")
    assert bin_size >= len(binary) and bin_size % 4 == 0
    with path.open("wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, total))
        f.write(struct.pack("<I4s", len(js), b"JSON")); f.write(js)
        f.write(struct.pack("<I4s", bin_size, b"BIN\0")); f.write(binary)
        f.seek(total - 1); f.write(b"\0")
    print(path, path.stat().st_size, "bytes")

limit = 150 * 1024 * 1024
write_glb(out / "limit_model_150.glb", "model", limit)
write_glb(out / "limit_animation_150.glb", "animation", limit)
write_glb(out / "over_limit.glb", "model", limit + 4)
