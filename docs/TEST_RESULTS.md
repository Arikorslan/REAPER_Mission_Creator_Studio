# Verification record — Mission Creator Studio 2.0.3

## Source and mission checks

- Godot 4.7.2 project import and headless launch passed. Source UI integration:
  **35/35** checks, including commands, terrain, assets, mission data,
  save/load, validation, self-contained export and responsive layouts.
- Imported-model and animation checks: genuine model and animated GLB fixtures
  padded to exactly **157,286,400 bytes (150 MiB)** each passed the actual
  Creator import and draft reload path, **8/8** checks each. A GLB just over
  the limit and an over-limit FBX were rejected, **4/4** checks. A real FBX
  animation padded to 150 MiB converted successfully; padding is not complex
  animation content.
- Actual mission exports containing those 150 MiB model/animation fixtures each
  finished, displayed byte-count write progress, reloaded the original asset
  at its full size and passed **7/7** checks. The independent v5 reader and
  installer passed **30/30** checks for each package.
- A Creator scene padded with unused bytes to **167,875,292 bytes** (about
  160 MiB) passed the separate scene-budget save/recheck/reload test,
  **12/12**; the same GLB exceeded the independent 150 MiB import budget.
  The v5 reader/installer passed **30/30** for that package. The Linux
  roundtrip process peaked at about **610 MiB RSS**, not a device requirement.
- The six-object painted example exported through the UI. Its package passed
  full Godot GLB reimport and **30/30** v5 reader/installer checks. V5 tests
  logged missing-splash warnings from the incomplete game source checkout.
- Scene structure and corruption checks: **11/11**, including comparison with
  full Godot reimport. A second **13/13** regression checked terrain-following
  road geometry, colliding/duplicate names, a hidden object, mission metadata,
  ZIP manifests and full reimport. Its mission also passed **30/30** v5 checks.
- Invalid-destination recovery: **11/11** checks. The expected filesystem error
  was reported; editing, auto-save, close/back actions and focused input were
  blocked during export; the worker joined, controls returned, the draft was
  preserved, and export to a valid destination succeeded.

## Progress and responsiveness

A Linux Xvfb/Mesa GUI run of the painted six-object example passed **8/8**
progress checks. The overlay rendered and 246 UI frames were observed while
exporting, with 26 distinct percentages and a maximum observed frame gap of
314 ms. A pixel comparison of the CPU ground bake and prior texture path
matched. GLB and ZIP exports each displayed a live overlay and passed **6/6**
format checks together. These software-rendered results are observations on
one environment, not guarantees for every device or workload.

Ground bake, serialization, writes and post-write structural/hash verification
run in workers. The detached export scene is built on the main thread in steps.
One object or mesh construction operation, GPU synchronization, file access or
an indivisible engine stage can still pause the UI. The progress percentage is
stage-based, not an estimated remaining time. Background export's structural
and placement checks plus hashes do not constitute a full engine reimport; the
latter was separately exercised on the examples and remains available through
the default `Store.verify_package` path.

The 150 MiB model test observed a maximum headless frame gap around 754 ms and
about 492 MiB peak process RSS. The fixtures contain real small geometry or
animation plus unused padding, so these are not representative measurements for
a complex 150 MiB model, terrain, Android device or a 512 MiB scene.

## Scope not established

The 512 MiB boundary, genuinely complex large terrain/models, complete mission
gameplay, native Windows, physical Android devices and an Android in-place
upgrade have not been tested. A compatible reader accepting a package does not
prove the game can render or play it on every device. The available game checkout
is missing original art assets. No responsiveness, memory or security guarantee
is implied. The source is recovered rather than pristine; signing credentials
are not included.
