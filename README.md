# REAPER Mission Creator — Studio Interface

An editable Godot 4.7.2 project based on the recovered Mission Creator 2.0.1,
with a new workspace designed from the supplied REAPER Studio v3 reference.
This is a **separate copy**; the original Creator and Studio inputs are not
modified. Build: 2026-11-07.

## Start here

### Windows build
1. Extract the entire `REAPER_Mission_Creator_Studio_Windows_x64.zip` to a
   normal folder and run `REAPER_Mission_Creator_Studio.exe`.
2. This build is **unsigned** and was generated on Linux; it has not been run
   on a Windows machine. Windows SmartScreen may warn about it. Review the source
   or ask a trusted administrator if you are unsure about running it.
3. If the default Vulkan renderer is unavailable, launch it from a command
   prompt with `--rendering-method gl_compatibility --rendering-driver opengl3`.

### Editable Godot project
1. Install **Godot 4.7.2**, open the project manager, select **Import**, and
   choose this folder's `project.godot`.
2. Wait for the initial import and press **F5** to run the main scene.
3. `export_presets.cfg` includes Windows x64 and Linux x86_64 release presets.
   Godot's matching export templates are needed to build binaries.

## Create a custom mission

1. In **Terrain**, choose a sculpt or paint tool. Select a ground surface,
   adjust brush radius/strength, and drag in the scene or editable map.
2. Switch to **Content** to search for and place assets. Click an asset to
   place it, or drag it into the scene/map. Use **Object** and **Scene** to
   edit objects, positions, routes and other properties.
3. Open **Mission**, name the mission, write its briefing and objective notes,
   select a placed object and press **Use selected as recon target**.
4. Run **Checks**, then use **Save** to retain an editable `.rmdraft`.
   Saving a draft alone does **not** create a game-importable mission.
5. Use **Export mission** to create a self-contained `.rmission`. An export
   requires a recon target; its embedded scene and asset hashes are checked.
   Keep both the draft and exported package.

Try **Open** with `examples/Operation_Sandglass.rmdraft` to explore a sample
with a command post, road, patrol route and painted terrain. Its matching
`examples/Operation_Sandglass.rmission` is included for importer tests.

At narrower widths, **Tools** and **Inspector** open/collapse the side panels;
the command ribbon scrolls horizontally. The map's labels avoid overlapping;
zoom in to see more. The first-person and flight controls, model/texture import,
heightmaps, 3D export and other recovered Creator functions remain accessible.
Press **F1** for in-app help. Common shortcuts include Ctrl+N, Ctrl+O, Ctrl+S,
Ctrl+Shift+S, Ctrl+E, Ctrl+Z, Ctrl+Y and Delete.

## What's included and what is not

- Studio-style dark shell, toolbar, menus, responsive side panels and the
  Creator's actual 3D viewport and editable map.
- **23 terrain colour presets:** five recovered Creator presets plus 18 Studio
  albedo textures, converted to JPEG for the Creator's existing codec. The
  Studio normal/roughness maps and its separate application features were not
  ported; these are colour surfaces, not a full Studio PBR material system.
- Several original built-in assets (including the house, compound, humvee and
  soldier) are simple **placeholder geometry**. Imported models can be used.
- The Creator produces a custom **recon** mission package. Objective notes are
  briefing text, not a general-purpose scripting or trigger system.
- The independent game-side reader/installer tests accepted the example and a
  GUI-exported mission (30/30 checks each). **Full in-game play is not verified
  in the current game checkout:** required game assets are missing. The game
  source contains importer/launcher APIs, but no player-facing `.rmission`
  import/launch control was found in the current menu. That menu wiring and a
  complete game build still need to be supplied/tested for players.
- The Windows export was packed and its embedded files were verified, but it
  has not been executed on Windows. A corresponding Linux release was launched
  and interacted with during testing. Use trusted models and mission files;
  hash checks verify integrity, not the identity or safety of a source.
- Large scenes and high-resolution models can require substantial memory.

## Source provenance and checks

The original application source was recovered from compiled Godot files;
comments and formatting could not be recovered. API-surface matching and
successful runs do not prove exhaustive behavioral equivalence. The project
contains the new UI and tests as well as the recovered application code; see
`docs/TEST_RESULTS.md` for the specific tests and limitations. Assets in this
project are derived from the supplied files.
