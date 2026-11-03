# Task 1 report: HoopTrace launcher icon

## Outcome

Generated a new HoopTrace launcher mark with the built-in ImageGen tool, normalized it into a transparent 1024 x 1024 safe-zone source, composited the opaque near-black master, regenerated all existing Android legacy and iOS AppIcon derivatives, and added Android adaptive, round, and Android 13 monochrome resources. No Flutter dependency, app page, route, package name, splash screen, data, or version changed.

## ImageGen mode and final selected prompt

- Tool mode: built-in ImageGen (no CLI/API fallback)
- Use case: `logo-brand`
- Intent: generate a new transparent square raster logo source
- Selected generation: first built-in output; the one allowed targeted correction was inspected but rejected because it baked a checkerboard into an RGB image instead of preserving transparency.

```text
Use case: logo-brand
Asset type: square mobile app launcher icon foreground source with true transparency
Primary request: Create one centered, minimal geometric basketball mark for HoopTrace: a basketball hoop and backboard in warm white, an arena-orange basketball at the upper left, and one continuous arena-orange shot trace curving from the ball into the hoop.
Scene/backdrop: fully transparent canvas; no background shape and no baked outer icon container.
Subject: simplified front-facing basketball backboard and hoop; the ball and continuous trace must remain distinct and recognizable at 32 px.
Style/medium: crisp flat vector-like logo rendered as a high-resolution raster; minimal silhouette; heavy square-ended strokes; generous negative space.
Composition/framing: square composition, optically centered as one balanced mark, with ample clear margin on every side for Android adaptive circle, rounded-square, and squircle masks; nothing clipped.
Color palette: use only warm white #F4F3EF and arena orange #FF5A1F; transparent elsewhere.
Constraints: exactly one basketball, one continuous shot trace entering the hoop, and one hoop/backboard assembly; clean simple geometry; strong small-size legibility; true alpha transparency.
Avoid: text, letters, lettermarks, red or blue player dots, a full basketball court, extra balls, extra traces, extra court markings, gradients, shadows, glow, paper texture, distressing, 3D effects, photorealism, watermark, border, background fill, and baked rounded outer corners.
```

## Generated and final saved paths

- Selected built-in output: `C:\Users\48029\.codex\generated_images\01a04864-81a3-77e0-a232-e5275fdc88ee\exec-e8e3cc89-d57a-44ee-9e1d-594326c494cb.png`
- Rejected correction output: `C:\Users\48029\.codex\generated_images\01a04864-81a3-77e0-a232-e5275fdc88ee\exec-247830f3-97e3-40bb-a3c1-496a37eebe3d.png`
- Final transparent foreground: `assets/icons/hooptrace-app-icon-foreground.png`
- Final opaque master: `assets/icons/hooptrace-app-icon.png`
- Visual contact sheet: `.superpowers/sdd/hooptrace-black-court-app-icon/task-1-contact-sheet.png`
- API 36 launcher screenshot: `.superpowers/sdd/hooptrace-black-court-app-icon/task-1-emulator-launcher.png`

## What changed

- Canonicalized ImageGen's visible mark to warm white `#F4F3EF` and arena orange `#FF5A1F`, retained true alpha, centered the visible bounds, and fit them within a 620 x 620 area on the 1024 x 1024 foreground canvas.
- Composited the foreground over exact near-black `#101112` to replace the opaque launcher master.
- Regenerated legacy Android mdpi through xxxhdpi mipmaps at 48, 72, 96, 144, and 192 pixels with Pillow Lanczos resampling.
- Regenerated every named iOS AppIcon PNG at the pixel dimensions declared by `Contents.json`; all outputs are opaque.
- Added mdpi through xxxhdpi adaptive foreground and one-color monochrome PNGs at 108, 162, 216, 324, and 432 pixels.
- Added v26 square/round adaptive XML, v33 square/round adaptive XML with monochrome references, the solid background color resource, and `android:roundIcon` in the manifest.
- Added `tool/release/generate_launcher_icons.py` so normalization, derivation, validation, and contact-sheet creation are reproducible with Pillow and no Flutter package dependency.
- Updated `assets/icons/README.md` with the final prompt, mode, palette, roles, derivation rules, and MIT source/licensing statement.

## Visual checks

Inspected the selected ImageGen output at native size. Its alpha bounds were clear of the canvas, but the composition needed safe-zone scaling and exact flat-color normalization. The only correction attempt improved margins but returned RGB with a baked checkerboard, so it was not used.

Inspected the final master, transparent foreground, and contact sheet at 1024, 192, 96, 48, and 32 pixel sampling on light and dark surroundings under circle, rounded-square, and squircle-style masks. The ball, orange trace, rim/backboard, and net remain recognizable; all masks retain clear margins with no clipping. At 32 pixels the fine net gaps soften, but the ball-to-hoop concept remains legible.

Installed the built APK on `emulator-5554` (Android 16 / API 36), launched the app, opened the Pixel launcher app drawer, and inspected the rendered circular adaptive icon next to its `HoopTrace` label. The mark was centered, crisp, recognizable, and unclipped.

## Programmatic checks

`tool/release/generate_launcher_icons.py` validates:

- the 1024 x 1024 foreground has both transparent and opaque alpha and stays within the configured safe zone;
- the opaque master is 1024 x 1024 and every fully transparent foreground pixel maps to exact RGB `(16, 17, 18)`;
- all legacy Android mipmaps have their density dimensions and no alpha;
- all adaptive foregrounds have density dimensions and alpha;
- every visible monochrome pixel is warm white and uses the foreground silhouette alpha;
- every named iOS PNG matches its catalog point-size/scale calculation and has no alpha;
- manifest icon and round-icon references are correct;
- v26/v33 adaptive resource references and the exact `#101112` color resource are correct.

## Verification commands and results

```powershell
py -3 tool\release\generate_launcher_icons.py --import-imagegen-source '<selected-built-in-output>' --contact-sheet '.superpowers\sdd\hooptrace-black-court-app-icon\task-1-contact-sheet.png'
```

Result: exit 0; foreground normalized, all resources generated, and validation passed.

```powershell
py -3 -m py_compile tool\release\generate_launcher_icons.py
py -3 tool\release\generate_launcher_icons.py --contact-sheet '.superpowers\sdd\hooptrace-black-court-app-icon\task-1-contact-sheet.png'
git diff --check
```

Result: exit 0; script compiled, deterministic regeneration and validation passed, and no whitespace errors were reported (Git emitted only the repository's expected LF-to-CRLF notices).

```powershell
flutter analyze
```

Result: exit 0; `No issues found!` in 11.2 seconds.

```powershell
flutter test
```

Result: exit 0; `+907: All tests passed!` in approximately 43 seconds.

```powershell
flutter build apk --debug
```

Result: exit 0; Gradle `assembleDebug` completed and produced `build/app/outputs/flutter-apk/app-debug.apk`.

```powershell
adb devices -l
flutter devices
adb -s emulator-5554 install -r 'build\app\outputs\flutter-apk\app-debug.apk'
adb -s emulator-5554 shell monkey -p io.github.x1a0y4ngren.hooptrace -c android.intent.category.LAUNCHER 1
```

Result: API 36 emulator detected; streamed install returned `Success`; launcher intent injected and app opened.

```powershell
adb -s emulator-5554 shell input keyevent KEYCODE_HOME
adb -s emulator-5554 shell input swipe 540 1750 540 350 700
adb -s emulator-5554 shell uiautomator dump /sdcard/hooptrace-launcher.xml
adb -s emulator-5554 shell screencap -p /sdcard/hooptrace-launcher.png
adb -s emulator-5554 pull /sdcard/hooptrace-launcher.png '.superpowers\sdd\hooptrace-black-court-app-icon\task-1-emulator-launcher.png'
```

Result: launcher hierarchy contained `text="HoopTrace"` / `content-desc="HoopTrace"`; screenshot was visually inspected.

## Files changed

- `assets/icons/README.md`
- `assets/icons/hooptrace-app-icon-foreground.png`
- `assets/icons/hooptrace-app-icon.png`
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/res/values/colors.xml`
- `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`
- `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml`
- `android/app/src/main/res/mipmap-anydpi-v33/ic_launcher.xml`
- `android/app/src/main/res/mipmap-anydpi-v33/ic_launcher_round.xml`
- `android/app/src/main/res/mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png`
- `android/app/src/main/res/drawable-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher_foreground.png`
- `android/app/src/main/res/drawable-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher_monochrome.png`
- all 15 PNGs currently named by `ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json`
- `tool/release/generate_launcher_icons.py`
- `.superpowers/sdd/hooptrace-black-court-app-icon/task-1-contact-sheet.png`
- `.superpowers/sdd/hooptrace-black-court-app-icon/task-1-emulator-launcher.png`
- `.superpowers/sdd/hooptrace-black-court-app-icon/task-1-report.md`

## Self-review

- Scope is limited to launcher icon sources, platform launcher resources, manifest wiring, icon documentation, the reproducible generation/validation script, and verification artifacts.
- No dependency manifest or lockfile changed; Pillow is an external release-tool prerequisite only.
- Existing iOS catalog names and dimensions were preserved; no catalog metadata changed.
- Android pre-v26 devices retain opaque legacy mipmaps, v26+ devices receive adaptive square/round resources, and v33+ devices receive the monochrome element.
- Re-running the generator without the ImageGen import reproduces and validates every platform derivative from the committed transparent foreground.
- `git diff --check`, analysis, all tests, Android resource compilation, APK install/launch, and launcher inspection passed before commit.

## Concerns

- The built-in correction attempt did not preserve transparency and was intentionally rejected; the selected first output is the source of record.
- The 32 pixel contact-sheet sample softens the smallest internal net gaps, although the ball, trace, rim, and overall hoop remain recognizable.
- The API 36 launcher was visually checked with its normal circular mask. The themed monochrome asset was validated programmatically but was not separately enabled in the emulator UI.

## Fix Round 1: legacy round-icon fallback

### Review finding and root cause

`AndroidManifest.xml` references `@mipmap/ic_launcher_round`, but the initial implementation supplied that name only as v26/v33 adaptive XML. The Pillow generator's legacy loop wrote only `ic_launcher.png`, so API 25 had no density-qualified PNG fallback for the manifest's round-icon resource.

### Red check

Added the legacy round-file existence/dimension/opacity assertions to `validate_resources()` before changing generation, then ran:

```powershell
py -3 tool\release\generate_launcher_icons.py
```

Result: exit 1 with the expected failure:

```text
AssertionError: Missing legacy launcher resource: D:\GitHub\hooptrace\.worktrees\hooptrace-1-1-comparison\android\app\src\main\res\mipmap-mdpi\ic_launcher_round.png
```

### Fix

Changed the Android legacy generation loop to write the same opaque Lanczos-resized composite to both `ic_launcher.png` and `ic_launcher_round.png` for mdpi, hdpi, xhdpi, xxhdpi, and xxxhdpi. The validator now requires both filenames at every density and checks their expected dimensions and lack of alpha.

Added files:

- `android/app/src/main/res/mipmap-mdpi/ic_launcher_round.png` (48 x 48 RGB)
- `android/app/src/main/res/mipmap-hdpi/ic_launcher_round.png` (72 x 72 RGB)
- `android/app/src/main/res/mipmap-xhdpi/ic_launcher_round.png` (96 x 96 RGB)
- `android/app/src/main/res/mipmap-xxhdpi/ic_launcher_round.png` (144 x 144 RGB)
- `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_round.png` (192 x 192 RGB)

### Verification commands and output

```powershell
py -3 tool\release\generate_launcher_icons.py
```

Result: exit 0; `Launcher icon resources generated and validated successfully.`

```powershell
py -3 -c "from pathlib import Path; from PIL import Image; root=Path('android/app/src/main/res'); sizes={'mdpi':48,'hdpi':72,'xhdpi':96,'xxhdpi':144,'xxxhdpi':192}; rows=[]; [(lambda p,s,d: (rows.append(f'{d}: {p.name} {Image.open(p).size} {Image.open(p).mode}'), (_ for _ in ()).throw(AssertionError(f'missing {p}')) if not p.is_file() else None, (_ for _ in ()).throw(AssertionError(f'bad size {p}')) if Image.open(p).size!=(s,s) else None, (_ for _ in ()).throw(AssertionError(f'alpha {p}')) if 'A' in Image.open(p).getbands() else None))(root/f'mipmap-{d}'/'ic_launcher_round.png',s,d) for d,s in sizes.items()]; print('\n'.join(rows)); print('Validated 5 legacy round icons: present, correctly sized, opaque.')"
```

Result: exit 0:

```text
mdpi: ic_launcher_round.png (48, 48) RGB
hdpi: ic_launcher_round.png (72, 72) RGB
xhdpi: ic_launcher_round.png (96, 96) RGB
xxhdpi: ic_launcher_round.png (144, 144) RGB
xxxhdpi: ic_launcher_round.png (192, 192) RGB
Validated 5 legacy round icons: present, correctly sized, opaque.
```

```powershell
git diff --check
```

Result: exit 0; no whitespace errors (only the repository's expected LF-to-CRLF notice for the Python file).

```powershell
flutter build apk --debug
```

Result: exit 0; Gradle `assembleDebug` completed in 14.5 seconds and produced `build/app/outputs/flutter-apk/app-debug.apk`.

```powershell
jar tf 'build\app\outputs\flutter-apk\app-debug.apk' | Select-String -Pattern 'res/mipmap-.*/ic_launcher_round.png'
```

Result: exit 0; the APK contains all five density fallbacks:

```text
res/mipmap-hdpi-v4/ic_launcher_round.png
res/mipmap-mdpi-v4/ic_launcher_round.png
res/mipmap-xhdpi-v4/ic_launcher_round.png
res/mipmap-xxhdpi-v4/ic_launcher_round.png
res/mipmap-xxxhdpi-v4/ic_launcher_round.png
```

```powershell
adb -s emulator-5554 install -r 'build\app\outputs\flutter-apk\app-debug.apk'
adb -s emulator-5554 shell am force-stop io.github.x1a0y4ngren.hooptrace
adb -s emulator-5554 shell monkey -p io.github.x1a0y4ngren.hooptrace -c android.intent.category.LAUNCHER 1
```

Result: streamed install returned `Success`; the launcher intent injected one event and the app opened on the API 36 emulator.

### Fix Round 1 self-review

- The change addresses only the missing legacy round-resource configurations; adaptive v26/v33 resources and the manifest remain unchanged.
- Standard and round legacy PNGs are derived from the same opaque master at the same density dimensions, so pre-v26 launchers can select either manifest resource without changing the visual mark.
- Validation fails on a missing file, wrong dimension, or alpha channel for either legacy filename.
- APK inspection confirms AAPT packaged every new fallback, and reinstall/launch confirms the rebuilt artifact remains installable and runnable.
- No new concerns were found in this fix round.

## Final Review Fix Wave: themed-icon evidence and alpha equality

### Validator hardening

`validate_resources()` now compares the complete alpha-channel bytes of each
density-specific `ic_launcher_monochrome.png` with the matching
`ic_launcher_foreground.png`. A monochrome resource with a different silhouette
now fails validation even when both files still contain the expected alpha
extrema.

Commands and results:

```powershell
py -3 tool\release\generate_launcher_icons.py
py -3 -B -m py_compile tool\release\generate_launcher_icons.py
git diff --check
```

Result: generator validation exited 0 with `Launcher icon resources generated
and validated successfully.`; Python compilation and whitespace validation also
exited 0. The only console message was Git's existing LF-to-CRLF notice.

### Android 13+ themed-icon visual check

On `emulator-5554` (API 36), opened the platform personalization page with:

```powershell
adb -s emulator-5554 shell am start -a android.settings.WALLPAPER_SETTINGS
adb -s emulator-5554 shell uiautomator dump /sdcard/window.xml
```

The UI hierarchy reported the `Themed icons` switch as `checked="true"`.
HoopTrace was then pinned from the app drawer to the home screen using the
launcher drag-and-drop gesture and captured with:

```powershell
adb -s emulator-5554 shell input draganddrop 940 1015 540 600 1800
adb -s emulator-5554 shell screencap -p /sdcard/home-themed.png
adb -s emulator-5554 pull /sdcard/home-themed.png `.superpowers\sdd\hooptrace-black-court-app-icon\task-1-emulator-themed-launcher.png`
```

Saved evidence:
`.superpowers/sdd/hooptrace-black-court-app-icon/task-1-emulator-themed-launcher.png`.
Visual inspection confirmed Pixel Launcher rendered the HoopTrace mark using a
single system palette color over the themed circular background. The ball,
continuous trace, backboard, rim, and net remained recognizable, centered, and
unclipped.

### Fresh final verification

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

Results: analyzer reported `No issues found!`; all 907 tests passed; the Debug
APK was rebuilt successfully at
`build/app/outputs/flutter-apk/app-debug.apk`.

### Final fix-wave self-review

- The tracked change is limited to one validator assertion; generated launcher
  assets remained deterministic and unchanged.
- The themed-icon visual check resolves the previously documented evidence gap.
- The alpha equality assertion directly covers the remaining validator-hardening
  recommendation.
- No new concerns were found.
