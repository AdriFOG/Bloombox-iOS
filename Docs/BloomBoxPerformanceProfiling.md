# BloomBox performance validation (optimizaciones)

**Scope:** iOS Home, Dock, living widgets, motion wallpapers, GameBox and LiveContainer guests.
**Do not publish or merge without device measurements.**

## Required A/B measurement

Build the same Xcode scheme and configuration from `main` (baseline) and
`optimizaciones` (candidate). Test on the **same device and iOS version**,
preferably plugged in, with identical wallpapers, apps, widgets and settings.
Reboot / let the device cool before each run. Alternate baseline and candidate
to reduce bias. Record at least three runs and report the median.

1. Xcode > Product > Profile > Instruments > **Time Profiler**.
   Record 60 seconds idle on Home (animated wallpaper, 4 moving widgets,
   1 GIF/HEVC widget), then 60 seconds of page swipes.
   Inspect main-thread samples, `body` recomputations, file reads and
   Core Animation / ImageIO / AVFoundation activity.
2. Repeat with the **Animation Hitches** instrument, with the same gestures
   and sustained 60-second idle captures. Record hitches, severity and
   time on the main thread. Compare no-animation, editing wobble and
   library-search blur separately.
3. Profile **launching and exiting a guest**. The Home should stop video,
   timers and moving widgets while the guest is foreground; no black
   screen may remain after the guest exits.
4. Import one large animated GIF as a wallpaper and as a media widget.
   Verify HEVC playback and transparency of media widgets. On devices
   without HEVC-with-alpha encoding, the original GIF fallback must still
   play. Validate Photos and Files import paths.
5. Repeat under `nominal`, `fair`, Low Power Mode/`serious` and (if
   naturally occurring) `critical`. **Do not deliberately overheat a phone.**
   After recovery, verify that decorative effects return only after
   45 seconds at the healthier thermal level.

## Data to record

| Scenario | Branch | Main-thread CPU % | Hitches per minute | Longest hitch (ms) | Memory MB | Comments |
|---|---|---:|---:|---:|---:|---|
| Home idle, animated | main / optimizaciones | | | | | |
| Home page swipes | main / optimizaciones | | | | | |
| Search, blur | main / optimizaciones | | | | | |
| Editing wobble | main / optimizaciones | | | | | |
| Guest running | main / optimizaciones | | | | | |
| Low Power Mode | main / optimizaciones | | | | | |

## Acceptance criteria

- No repeated synchronous `UIImage(contentsOfFile:)` or `fileExists`
  calls from Home/Widget render bodies.
- No 30 FPS `TimelineView` used for living-widget motion or editing wobble.
- Only one Home Dock and page control, regardless of the page count.
- Paused/missing media and failed HEVC conversion never crash Home.
- Loss of optional visual effects must not interrupt guest launches,
  GameBox selection, JIT, app management or drag/drop.
- Check GIFs with transparency and video-first-frame posters on real hardware.
- **Frame rate:** Core Animation's 30 FPS preference is a hint, not an
  app-wide guarantee. Do not report a locked 30 FPS without measurements.

## Current status

Code changes and GitHub Actions builds can be validated in CI. The actual
Time Profiler / Animation Hitches measurements require an iOS device attached
to Xcode; no fabricated baseline values are included here.
