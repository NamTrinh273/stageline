---
name: setlist-prep-helper
description: >-
  Use when the user provides raw song lyrics, a concert tracklist, or .txt/.lrc
  notes and wants to generate a clean, ready-to-import .concert JSON package
  with [Chorus]/[Sing-along] highlights and optional short translations.
---

# Setlist Prep Helper (Generate Ready-to-Import `.concert` Files)

## Purpose
Help the user turn raw lyrics or a setlist into a clean, ultra-light `.concert` JSON file before attending a concert.

## Steps
1. **Normalize structure**:
   - Group lyrics into concise concert-readable sections (`Intro`, `Verse 1`, `Pre-Chorus`, `Chorus`, `Verse 2`, `Bridge`, `Outro`).
   - Keep each line short enough to read in a single glance on mobile (split overly long lines at natural phrasing pauses).
2. **Mark Sing-Along Highlights**:
   - Set `"singAlong": true` on `Chorus`, crowd chant parts, or iconic hook lines the user identifies.
3. **Optional 1-Line Translation (`"tr"`)**:
   - Only add `"tr"` when requested by the user (e.g., for US-UK songs); keep each `"tr"` concise (1 short line matching the lyric's meaning).
   - For V-pop songs or when translation is not requested, omit `"tr"` completely to save bytes.
4. **Validate Schema & QR Budget**:
   - Conform strictly to `.concert` schema `v: 1` (see `concert-lyrics-parser` skill).
   - Output valid UTF-8 JSON (minified when exporting for sharing, or pretty-printed if the user wants to inspect/edit first).
   - If the user intends to share individual songs via QR, verify each song's JSON stays comfortably under ~2.5 KB raw (which compresses well below the 2,200-char QR cap).
5. **Save Output**:
   - Save generated setlist files under `setlists/<concert-slug>.concert` (or the user's requested path) and confirm song count + total file size in KB.
