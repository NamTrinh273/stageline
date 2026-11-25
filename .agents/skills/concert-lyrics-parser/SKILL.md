---
name: concert-lyrics-parser
description: >-
  Use when designing, implementing, or testing the .concert JSON schema,
  parsing .txt/.lrc lyrics with [Verse]/[Chorus]/[Sing-along] tags, or encoding/decoding
  Gzip+Base64 single-song QR payloads.
---

# Concert Lyrics Parser & Offline Codec

## 1. Canonical `.concert` JSON Schema (v1)
Keep keys short to minimize file and QR payload size.

```json
{
  "v": 1,
  "id": "uuid-or-slug",
  "setlist": "Concert Title",
  "artist": "Artist Name",
  "updatedAt": "2026-11-25T18:00:00Z",
  "songs": [
    {
      "id": "s1",
      "title": "Song Title",
      "sections": [
        {
          "tag": "Verse 1",
          "singAlong": false,
          "lines": [
            { "t": "Original lyric line", "tr": "Optional concise translation" }
          ]
        },
        {
          "tag": "Chorus",
          "singAlong": true,
          "lines": [
            { "t": "Crowd sing-along line" }
          ]
        }
      ]
    }
  ]
}
```

Rules:
- Omit `"tr"` completely when empty/null (do not write `"tr": ""`).
- `"v"` MUST be integer `1` for forward-compatible migrations.

## 2. Raw Text (`.txt`) & `.lrc` Import Rules
1. Strip UTF-8 BOM and normalize line endings (`\r\n` -> `\n`).
2. For `.lrc` files:
   - Extract metadata tags (`[ti:...]`, `[ar:...]`) if present.
   - Strip leading timestamps matching `^\s*(\[\d{1,2}:\d{2}(?:[.:]\d{1,3})?\])+` from each line.
   - Ignore empty timestamp-only lines unless used as blank section breaks.
3. Section headers:
   - Match bracketed labels on their own line: `^\[(.+)\]$` (case-insensitive).
   - Set `singAlong = true` automatically when tag matches `chorus`, `sing-along`, `singalong`, `crowd`, `hook`, or `fan`.
   - Default untagged leading lines to section `tag: "Verse 1"`, `singAlong: false`.
4. Inline optional translation syntax (for quick paste):
   - A line starting with `>` or `|` immediately below a lyric line attaches as `tr` to the previous line (e.g. `> Bản dịch ngắn`).

## 3. Single-Song QR Codec (`dart:io` `gzip` + `base64Url`)
- Prefix payload with `SL1:` (StageLine v1) so scanner instantly rejects unrelated QR codes.
- Encode a **single `Song` JSON** (`utf8.encode` -> `gzip.encode` -> `base64Url.encode`).
- Hard safety cap for reliable low-light scanning: **2,200 characters** total (`SL1:` + base64).
  - If compressed song exceeds 2,200 chars, warn user and offer `.concert` file export instead of generating an unreadable dense QR.
- Validate on decode: check `SL1:` prefix, guard against malformed base64/gzip (catch `FormatException` / `IOException`), and cap decompressed size at `64 KB` (zip-bomb protection).

## 4. Verification
Run in one command after edits:
```powershell
flutter test test/core/parser/ ; flutter analyze lib/core/parser/
```
