---
name: flutter-lightweight-ui
description: >-
  Use when building or reviewing Flutter UI screens, Riverpod state,
  Concert Mode (OLED theme, Tap-to-Advance, Quick Section Jump, Extra Dim,
  WakeLock), or optimizing frame/battery performance.
---

# Flutter Lightweight & Concert Mode UI Guide

## 1. State Management Pattern
- Use `flutter_riverpod` standard `Notifier` / `AsyncNotifier` (NO `riverpod_generator` or `build_runner` to keep builds fast and dependencies lean).
- Isolate frequently changing UI state (current active line index, dim level, HUD visibility) in small dedicated providers or `ValueNotifier` so the entire lyric list does not rebuild on every tap.

## 2. Concert Mode Core UX Contract
1. **True OLED Black**: Scaffold background `#000000`. Avoid elevation shadows and translucent blurs (`BackdropFilter` drains GPU/battery).
2. **Anti-Glare Readability**:
   - Active line: `#E2E2E6` (or `#FFD166` when `section.singAlong == true`), bold/medium weight, slightly higher contrast.
   - Surrounding lines: `#8E8E93` (dimmed so the eye snaps immediately to the active line).
   - Optional translation (`tr`): `#6E6E73`, smaller font size (`fontSize * 0.72`), toggled by 1 tap in HUD.
3. **Tap-to-Advance + Free Scroll**:
   - Use invisible gesture zones or `GestureDetector(behavior: HitTestBehavior.translucent)` layered cleanly with `Scrollable`:
     - Bottom 65% tap: advance active line (+1) and smoothly auto-center it (`Scrollable.ensureVisible` or calculated `ScrollController.animateTo` ~220ms `Curves.easeOutCubic`).
     - Top 25% tap: step back (-1).
     - Top 10% header strip: toggle minimal HUD + swipe horizontally to switch `Prev / Next` song in the current setlist.
   - Manual drag scroll MUST never fight the user; do not snap back while user is dragging.
4. **Quick Section Jump Bar**:
   - Compact horizontal pill bar pinned at the bottom (`[V1]`, `[Pre]`, `[CHORUS]`, `[V2]`, `[Bridge]`).
   - Highlight `singAlong` pills with subtle `#FFD166` border.
   - Tapping a pill jumps directly to the first line of that section and updates the active line index.
5. **Extra Dim Overlay**:
   - Render an `IgnorePointer` `ColoredBox(color: Colors.black.withValues(alpha: dimAlpha))` above the Scaffold body (`dimAlpha` from `0.0` to `0.75`), paired with `screen_brightness` control.

## 3. Hardware Lifecycle Safety (Mandatory)
- On entering Concert Mode: enable `WakelockPlus.enable()`, store original brightness if adjusted, optionally lock orientation if toggled.
- On `dispose()` AND app lifecycle `AppLifecycleState.paused`/`inactive`: call `WakelockPlus.disable()` and `ScreenBrightness().resetApplicationScreenBrightness()`.
- On QR Scanner screen: always `dispose()` `MobileScannerController` cleanly so camera never stays active in background.

## 4. Verification
Run after UI edits:
```powershell
dart format . ; flutter analyze ; flutter test test/features/
```
