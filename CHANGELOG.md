# Changelog

This fork collects the fixes from the community forks of [Leviidev/Henge](https://github.com/Leviidev/Henge)
into one build, with a few additions, aimed above all at iPad (tested hardware: iPad Pro M4).
Every change keeps its original author in the git history.

## Unreleased — A13 and iOS 15

- **A13 support.** The virtual CPU no longer advertises the Armv8.5 `SB` and `FRINTTS`
  extensions, which an A13 (Armv8.4) does not have and faulted on. The translator turns
  `SB` into a NOP and emulates `FRINT32Z/X` and `FRINT64Z/X` in a helper, with the overflow
  and FPSCR behaviour of the architecture. The chip gate now allows A13 (`iPhone12,x`,
  `iPad12,x`) instead of requiring A14.
- **iOS 15 floor.** The app, engine and restore libraries deploy to iOS 15.0 instead of 17.0.
  The SwiftUI that needed 16/17 (`NavigationStack`, `NavigationLink(value:)`,
  `LabeledContent`, `ShareLink`, `persistentSystemOverlays`, `scrollContentBackground`) is
  replaced by the shims in `Henge/Compat15.swift`, and the external display scene compares
  `UISceneSession.Role.rawValue` so it still works below iOS 16. UIKit and Metal calls newer
  than 15 (`UIHostingController.sizingOptions`, EDR headroom, `gpuAddress`/`gpuResourceID`,
  vertex attribute strides) are only used when available. On iOS 15 on A12 or newer,
  install the `.tipa`: iOS refuses the `dynamic-codesigning` entitlement on those devices, so
  the plain `.ipa` crashes when TrollStore launches it.
- **Graphics.** macOS's Metal libraries are relabelled for iOS 15 (AIR 2.4, library
  file 2.5, `air64_v24-apple-ios15.0.0`) instead of iOS 17, since the older Metal
  runtime refuses a library built for a newer OS.
- **JIT status means a region is held.** `JITBootstrap.ready` used to answer "On" as soon as
  the process was marked debugged (`CS_DEBUGGED`), which TrollStore's enable-jit and Dopamine's
  *Allow JIT in Apps* both do, without a region existing. The installer therefore started and
  then failed with "Henge has no JIT region". Status now reports a region only after one is
  actually claimed and self-tested; the self-grant route (MAP_JIT or plain memory) claims it
  there too, instead of leaving it for QEMU, which the iOS installer never asks to map its own.
  Settings also shows whether the region is held and why a claim failed.
- **Smaller devices** suggest 3 GB for a new Mac on a 3 GB iPhone, and an install no longer
  gives the restore system all of it. The restore fills whatever RAM it is given (it caches the
  ~15 GB it writes), so on a 3 GB iPhone the old 4 GB cap left nothing for iOS: the phone started
  paging and iOS killed Henge at the start of "Write macOS" with no crash report. The restore now
  gets 2 GB there (2.5 GB on 4 GB phones, 3 GB on 6 GB phones, 4 GB from 8 GB up) and the code
  region is 512 MB on 3/4 GB phones. Guest RAM keeps the engine's default backing (anonymous RAM
  outside the memory limit, the RAM file only as a fallback): forcing the file to make the pages
  evictable was tried, and the emulated restore kernel then went quiet a few seconds into boot and
  never took over from iBoot, even with five minutes. The install logs process memory every 10 s
  and iOS's memory warnings, so a memory kill can be told from a crash.
- **Restore-mode timeout.** idevicerestore waits 30 seconds for the device to leave recovery mode
  after the kernelcache is sent, while the emulated Mac's restore kernel takes longer than a real
  iPhone's to take over and re-enumerate. The install failed with "Failed to place device in restore
  mode" while the guest was still starting. That wait, the restore-reboot wait and the restore-mode
  reboot wait are now five minutes, and the install logs what every guest CPU is doing every 10 s so
  a stalled boot can be told from a slow one.
- **Install diagnostics actually run.** Neither was reaching the log: the install path never set the
  engine's stats interval (only a normal Mac boot did), and `HV_HEARTBEAT` was unset as soon as
  `hv_vm_start` returned, before the thread that reads it had started. The interval is now applied
  when the machine is built, the heartbeat is read synchronously at start, and its line also reports
  each CPU's PC, the code-cache use, and the host's free and compressed memory. Install progress is
  logged every 1% instead of every 10%.
- CI takes the prebuilt iOS libraries from [Husk 15](https://github.com/the6u6/Husk15-AI-made),
  built against an iOS 14 floor.

## 0.2.0 (100)

Based on upstream `main` at b744a78.

### Display colour
- macOS no longer looks pale: the half-float display surface is shown as WindowServer wrote it
  instead of being sRGB-encoded a second time. Colour probe for diagnosis (`HV_COLOR_PROBE`).
  — [hungbenjamin402](https://github.com/hungbenjamin402/Henge)
- Colour matching for the iPad's P3 panel (the Mac's frames are tagged sRGB), with live
  *Color matching*, *Linear color conversion* and *Brightness* controls in the session's Details.
  — [sonnx0868](https://github.com/sonnx0868/Henge)

### iPad, Magic Keyboard and trackpad
- Magic Keyboard scrolling calibrated, smoother input, and the device's thermal state in Details.
- Smaller, sharper pointer on iPad, with a size and a sharp-edges setting.
- Video planes copied through the IOSurface's real layout.
  — all three: [sonnx0868](https://github.com/sonnx0868/Henge)
- iPadOS's own hide-keyboard key ends typing, so the Mac takes the full screen again.
  — [gavinnolan](https://github.com/gavinnolan/Henge)
- Screen modes for a Mac on iPad: *Retina* (every pixel of the panel, at 2x), *Performance*
  (about 30% fewer pixels), *Fit this iPad* and *16:9*. Retina is opt-in: it costs a lot of
  emulated GPU work.
  — Retina from [AdamLovattDevOps](https://github.com/AdamLovattDevOps/Henge), Performance from sonnx0868
- 120 Hz ProMotion support, 4 GB default memory on 8 GB iPads, sampling profiler and GPU
  trace/shader dump tools. — [AdamLovattDevOps](https://github.com/AdamLovattDevOps/Henge)

### External display
- A Mac on an external display before iOS 27 too (iOS 17–26), the picture coming back to the
  device when the monitor is unplugged, and unplugging one display no longer freezes the others.
  — [hungbenjamin402](https://github.com/hungbenjamin402/Henge)

### JIT
- At launch, LocalDevVPN is connected first when it is off.
  — [braedonsaunders](https://github.com/braedonsaunders/Henge) (upstream PR #3)
- JIT on cellular: explains the failure and retries instead of blaming LocalDevVPN.
- Personal (free) teams can sign the app: `HENGE_ENTITLEMENTS`.
  — both: [hungbenjamin402](https://github.com/hungbenjamin402/Henge)

### New in this fork
- **Performance settings** (Settings → Performance), applied each time a Mac starts:
  - *Mac refresh rate*: 60 Hz by default. Every frame is emulated and replayed, so 120 Hz
    halves the CPU left to apps; 120 Hz stays available.
  - *Faster disk writes* (on): `F_BARRIERFSYNC` instead of a full `fsync`.
  - *Quicker wake from idle* (off): an idle CPU watches for work for 50 µs before sleeping.
  - *Superblocks (experimental)* (off): translated code runs on past conditional branches.
  - `Documents/henge-env.txt` still overrides everything.
- **Hide the session controls**: a button left of Keyboard hides the bar over the Mac; a
  three-finger tap brings it back (a hint says so the first three times). iPadOS's own
  three-finger undo/copy/paste bar is turned off inside the session so it doesn't interfere.
- Merges kept the Xcode 27 build: the built-in StikJIT helper and the Liquid Glass icon stay
  (the m4 fork's Xcode 16 changes, which remove them, are left out).
- Display name back to *Henge*; version 0.2.0 (100) so sideloading stores treat it as an update.

### Not included
- `HV_GROUPS` (grouped memory accesses): upstream measured it no faster and it fills the JIT
  region sooner.

## Building

As upstream (see README): Xcode 27, `xcodegen`, `meson`, `rustup` with `aarch64-apple-ios`,
and a built [Husk 15](https://github.com/the6u6/Husk15-AI-made) at `~/Documents/Coding/Husk`. Only Husk's
`build_ios.sh libffi glib libslirp` and `build_rppairing_ios.sh` are needed for Henge.
