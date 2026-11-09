# Build verification — Mission Creator Studio 2.0.3

## Windows x64

- The final standalone executable is a 64-bit Windows PE and is unsigned.
- All 127 embedded Godot PCK files were extracted and matched their stored
  MD5 checksums. All six icon resources matched the previous Creator build.
- The actual 2.0.3 executable launched under Wine/Xvfb. Its GUI opened the
  included six-object draft, displayed the progress overlay, and completed a
  self-contained mission export. The independent v5 reader/installer passed
  **30/30** checks on that exported file. This is not a native Windows test.

## Android

- The final APK's ZIP CRCs and zip alignment passed. Its ARM64 and ARMv7
  libraries, launcher icons, manifest and signature were checked. All 25
  launcher icon entries matched the previous APK.
- Package: `org.reaperoperations.missioncreator`, versionCode **5**,
  versionName `2.0.3-studio-150-assets`, min SDK **24**, target SDK **36**.
- APK signing schemes v2/v3 verified. The signing certificate SHA-256 is
  `c104f3328b04d5d391d94e9390f168d50cc7e69345e9e9407da30aa7cbe189c4`,
  matching the previous APK. No private key or signing password is included in
  this source archive. An actual Android install/update was not tested.

## Compiled scripts

The 44 compiled scripts extracted from the final EXE and APK matched each
other. When run under desktop Godot 4.7.2, each platform's extracted scripts
passed the **13/13** scene regressions, **11/11** export recovery checks, and
**12/12** padded-160-MiB scene regression. The Windows scripts also passed the
actual padded-150-MiB model mission export (**7/7**), and the Android scripts
passed the padded-150-MiB animation mission export (**7/7**). These are
compiled-script tests on desktop, not tests on Android hardware.

See `TEST_RESULTS.md` for fixture limitations, responsiveness observations and
untested cases.
