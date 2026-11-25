# StageLine — Offline Concert Lyrics App (Flutter)

## Core Constraints (Always Enforced)
- **Target**: Flutter (Android & iOS), 100% offline, zero backend, APK target `<18 MB` (`arm64-v8a`).
- **Allowed Packages ONLY** (ask user before adding any other dependency):
  `flutter_riverpod`, `path_provider`, `wakelock_plus`, `screen_brightness`, `qr_flutter`, `mobile_scanner`, `file_picker`, `share_plus`.
- **Storage**: Plain JSON files via `dart:io` + `path_provider` (NO Isar/ObjectBox/Realm/Firebase).
- **Compression**: Use `dart:io` `gzip` built-in (no external compression packages).
- **Typography**: System fonts only (Roboto / SF Pro); no bundled custom fonts.

## OLED Concert Palette
- Background: `#000000` (true OLED black)
- Primary lyric text: `#E2E2E6` (anti-glare off-white, never `#FFFFFF`)
- Sing-along / Chorus highlight: `#FFD166` (warm gold) + left accent bar
- Optional translation line: `#8E8E93` (muted gray, toggleable)
- Active line / focus surface: `#121216`

## Repository Map (Planned `lib/` Structure)
- `lib/core/models/` — Immutable Dart models (`Setlist`, `Song`, `LyricSection`, `LyricLine`)
- `lib/core/parser/` — `.concert`, `.lrc`, `.txt` parsers & Gzip+Base64 QR codec
- `lib/core/storage/` — `ConcertRepository` (local JSON file store)
- `lib/features/setlists/` — Setlist list, detail, drag-reorder, quick paste/editor
- `lib/features/concert_mode/` — OLED reader, Tap-to-Advance, Quick Section Jump, WakeLock, Extra Dim
- `lib/features/share/` — Single-song QR generate/scan & `.concert` file import/export

## Hydrogen / Neon Agent Workflow Rules (Token Efficiency)
- **Neon (High/Medium)**: Owns `lib/core/` models, interfaces, parser, QR codec, Concert Mode gesture/scroll engine, and end-of-phase audits.
- **Hydrogen (Medium)**: Implements full vertical feature slices in `lib/features/` + platform/CI config strictly against `lib/core/` contracts.
- **Hydrogen (Low)**: Batches unit/widget tests, mock setlists, and lint fixes in minimal turns.
- **Verify in one command**: Run `dart format . ; flutter analyze ; flutter test` instead of manual static review.
- **Activate skills on demand**: Load `.agents/skills/<name>/SKILL.md` only when working in that domain.
