# Verification record — 2026-11-07

## Automated checks

- Godot 4.7.2 import and headless launch: passed.
- `godot --headless --path . --script tests/test_ui_integration.gd`: **35/35**.
  Tests real UI command connections, all 23 preset hashes/codecs, search and
  placement, inspector edits, mission fields and recon target, terrain sculpt,
  brush and texture settings, routes, undo/redo, draft save/load, validation,
  self-contained export, and responsive layouts at 1600, 1024 and 800 pixels.
- `tests/test_ui_gui.gd` under Xvfb/Mesa GL: passed; the normal GUI export
  callback created a package and displayed the verified-success dialog without
  expanding the one-line status bar.
- GUI exports of the included six-object, painted Operation Sandglass draft
  succeeded at 1280×720 and 1600×900 under Xvfb/Mesa; these exercised the normal
  stepped export path with the technical-truck model and road. A pre-optimization
  run was killed under the roughly 2 GB software-rendering environment. The
  exporter was changed to release temporary export resources and discard image
  decoding during the geometry/placement recheck; both sizes then passed. The
  output retains its images and the package hashes the complete asset bytes.
- The game checkout's independent `tests/rmission_pipeline_test.gd` passed
  **30/30** for the example mission and **30/30** for a GUI-exported mission,
  using isolated test user-data directories. It read and verified the package,
  built a mission specification, installed, reloaded and uninstalled it.
- The Linux release launched both headlessly and graphically. Real mouse/keyboard
  input was used to select a content asset, edit a mission name, open the painted
  six-object example and export that package from the file dialog. The eight screenshots are actual rendered
  frames, not mockups; the six main shots use a scripted real app session.
- Windows x64 release: Godot export succeeded. Its embedded PCK was extracted
  and **all packed entries passed MD5 verification**, including all 18 Studio
  textures. **The executable has not been run on Windows.**

## Important limits

Passing the independent importer/installer pipeline does not prove actual
in-game playback, behavior of every tool, or compatibility with every graphics
driver. The currently available game checkout is missing many required assets;
a full gameplay test was not possible. Its launcher/installer APIs exist, but
no player-facing `.rmission` import/launch button was found in the current game
menu. Studio albedo textures only were ported, not its PBR material system.
Some built-in models are explicitly placeholders. Mission objective notes are
not programmable triggers.
