# REAPER Mission Creator Studio 2.0.3

Editable Godot project for creating REAPER Operations custom missions. This
version raises the model and animation import limit to **150 MiB each** and adds
a live, stage-based progress display for mission, GLB and 3D ZIP exports.
The exported-scene limit remains 512 MiB. See `docs/TEST_RESULTS.md` for the
checks performed and what remains untested.

## Run the applications

### Windows

Run `REAPER_Mission_Creator_Studio_2.0.3_Windows.exe` on 64-bit Windows. It is
a standalone executable. The file is **unsigned**, so Windows SmartScreen may
warn before running it. If the default renderer is unavailable, try:

```
REAPER_Mission_Creator_Studio_2.0.3_Windows.exe --rendering-method gl_compatibility --rendering-driver opengl3
```

### Android

`REAPER_Mission_Creator_Studio_2.0.3_Android.apk` targets ARM64 and ARMv7 on
Android 7.0 / API 24 or newer. It retains the previous Creator package ID and
is signed with the same certificate, with a higher version code. It is intended
to update the corresponding 2.0.1/2.0.2 app in place, without uninstalling.
Back up drafts and missions first. A physical-device installation or upgrade
has not been tested; Android will reject an update if the installed app has a
different signing certificate. Installing a downloaded APK may require granting
permission to the app used to open it.

## Create a mission

1. In **Terrain**, sculpt or paint the ground and choose a surface.
2. Use **Content** to place assets. Use **Object** and **Scene** to edit them.
3. Open **Mission**, name it and enter the briefing. Select an object and choose
   **Use selected as recon target**.
4. Run **Checks**, then **Save** an editable `.rmdraft`.
5. Choose **Export mission** to create a self-contained `.rmission`. Keep the
   draft as well as the export. Import the mission into the compatible REAPER
   Operations v5 build.

The included `examples/Operation_Sandglass.rmdraft` has a painted six-object
scene, a road and a patrol route. Press **F1** for in-app help. On narrower
screens, **Tools** and **Inspector** expand the collapsed side panels.

## Export progress

The progress window is shown for mission, GLB and ZIP exports. Major work such
as ground baking, serialization, writing and verification runs in background
tasks; scene construction is spread over frames. The percentage represents
completed **stages and work**, not estimated remaining time. Some stages are
indivisible and can hold the same percentage while the activity indicator
moves. Editing, autosave and normal close/back actions are paused during an
export. Keep the app open until it finishes. A failed write returns to the
editor and reports the error; choose another destination and retry.

Complex individual models, terrain construction, graphics-driver synchronization
or slow storage can still cause pauses. Responsiveness and memory use depend on
the actual content and device; no universal freeze-free or performance guarantee
is possible. In particular, large assets can also take time to **import** before
an export starts.

## Limits and memory

- Imported GLB model **or animation**: up to **150 MiB** (157,286,400 bytes)
  per asset. An FBX input may also be up to 150 MiB, and its converted GLB must
  fit the same 150 MiB limit. Conversion can increase size. Some formats and
  compression extensions remain unsupported.
- Exported scene GLB: **512 MiB** (536,870,912 bytes).
- Full Creator mission container: **1 GiB** (1,073,741,824 bytes); the scene,
  original assets and metadata all share this container budget.
- Texture assets: 16 MiB each; mission metadata: 4 MiB. Existing limits on
  object count, source archives and other validations also remain in force.
- Segmented writes avoid constructing another full container in memory. Scene
  building, textures, validation and loading can still require substantially
  more RAM than the file size. A size ceiling is not a promise that a particular
  phone or PC can export, import or play a scene of that size.

## Open and rebuild the source

1. Install **Godot 4.7.2**, import this folder's `project.godot`, wait for the
   initial asset import and press **F5**.
2. Install matching Godot 4.7.2 export templates. The included presets cover
   Windows x64, Linux x86_64 and Android.
3. Android export also needs a compatible JDK and Android SDK configured in
   Godot. Release-signing fields are blank: credentials and signing keys are
   **not included**. To update an existing installation, use the same signing
   certificate and a higher version code. A different certificate requires a
   separate installation strategy and may not retain the app's data.
4. The Windows release preset does not sign the executable. Its icon and the
   Android launcher/adaptive icon artwork are included.

## Compatibility and limitations

The independent v5 game reader/installer accepted the tested missions, including
packages with padded 150 MiB assets and a padded scene above 150 MiB. Padding
exercises file-size and package paths, not real complex geometry. Gameplay of a
genuinely large scene, the 512 MiB boundary, native Windows, and physical Android
have not been tested. Some built-in assets are placeholder geometry; objective
notes are briefing text, not programmable triggers. Use trusted models and
missions: hashes detect corruption, not the safety or identity of their author.

## Source provenance

Creator code was recovered from compiled Godot scripts; original comments and
formatting could not be recovered. This editable archive includes the recovered
code, Studio UI, assets, export presets, examples and tests. It is not a pristine
copy of the original source, and the checks do not prove exhaustive equivalence.
