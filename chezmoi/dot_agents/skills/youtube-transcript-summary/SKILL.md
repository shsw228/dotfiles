---
name: youtube-transcript-summary
description: Fetch a YouTube video's auto-generated transcript via `uvx yt-dlp` (no global install), clean the rolling-caption duplicates, and produce a structured summary or note from the result. Use whenever the user supplies a YouTube URL and asks for a summary, transcript, note, or "make a note from this video". Always uses `uv` — never installs `yt-dlp` globally. If `uv` is missing, asks the user before installing it.
---

# YouTube Transcript Summary

Use this skill whenever the user gives a YouTube URL (`youtube.com/watch?v=...`, `youtu.be/...`, `youtube.com/live/...`, `youtube.com/shorts/...`) and wants any of:

- a summary
- a structured note
- a literature note in the Notes vault
- the raw transcript itself
- chapter-by-chapter breakdown

## Core Rules

1. **Never `pip install` or `brew install` `yt-dlp` globally.** Always invoke it through `uvx`, which runs it in an ephemeral `uv`-managed environment.
2. **`uv` is the only dependency.** If it is missing, ask the user before installing it.
3. **Clean up temp files** (`*.vtt`, `*.info.json`) under `/tmp` after producing the output.

## Step 1 — Ensure `uv` is available

Check in this order:

```bash
command -v uv || ls ~/.local/bin/uv 2>/dev/null
```

- If found at `~/.local/bin/uv` but not on `$PATH`, use the absolute path `~/.local/bin/uvx` for the subsequent commands. Do not modify the user's shell config without permission.
- If `uv` is **not installed**, ask the user:
  > `uv` が見つかりません。`curl -LsSf https://astral.sh/uv/install.sh | sh` で公式インストーラを実行してよいですか？
  
  Only run the installer after explicit confirmation. After install, `uv` and `uvx` live at `~/.local/bin/`.

Never fall back to `pip`, `pipx`, or `brew` for `yt-dlp`.

## Step 2 — Extract the video ID

Accept these forms and extract the 11-character ID:

- `https://www.youtube.com/watch?v=<ID>`
- `https://youtu.be/<ID>`
- `https://www.youtube.com/live/<ID>`
- `https://www.youtube.com/shorts/<ID>`

Use the ID as the `/tmp/<ID>.*` filename stem.

## Step 3 — Fetch metadata and subtitles

Run these two commands (in parallel is fine):

```bash
# Metadata: title, description with chapters, uploader, duration
uvx yt-dlp --skip-download --print "%(title)s" --print "%(uploader)s" --print "%(duration_string)s" --print "%(upload_date)s" --print "%(description)s" "<URL>"

# Subtitles: prefer manual, fall back to auto-generated; English first, then any
uvx yt-dlp --skip-download \
  --write-sub --write-auto-sub \
  --sub-lang "en.*,ja.*,en,ja" \
  --sub-format vtt \
  -o "/tmp/<ID>.%(ext)s" \
  "<URL>"
```

Flags worth knowing:

- `--write-sub` first tries human-uploaded captions; `--write-auto-sub` adds YouTube's auto-generated ones as a fallback.
- `--sub-lang "en.*,ja.*,en,ja"` lets a regional variant (e.g. `en-US`, `en-orig`) satisfy the request. Add more languages if the user asks.
- The downloader may emit a warning about `deno`/JS runtimes — this is non-fatal for subtitle-only runs; ignore it.

If neither manual nor auto subs are available, the file will be missing. Tell the user that captions are unavailable for that video and stop — do not download the audio/video to transcribe locally unless the user explicitly asks.

## Step 4 — Clean the VTT

YouTube auto-VTT uses a rolling/karaoke format: every word emits its own cue with inline `<00:00:00.000>` timestamps and the previous line is repeated for paint-on. Raw VTT is ~10× longer than the actual text.

Use the helper script bundled with this skill:

```bash
uv run --no-project python3 ~/.claude/skills/youtube-transcript-summary/scripts/clean_vtt.py /tmp/<ID>.*.vtt > /tmp/<ID>.txt
```

The script:

1. Strips `WEBVTT`/`Kind:`/`Language:` headers and cue-timing lines.
2. Removes `<c>` tags and inline `<HH:MM:SS.mmm>` word-level timestamps.
3. Decodes `&gt;&gt;` → `>>` and other HTML entities.
4. Deduplicates consecutive repeated lines and lines that are wholly contained in their predecessor (the rolling-caption overlap).

## Step 5 — Produce the output

Pick the output shape from what the user asked for:

- **"要約して" / "summarize"** → write a Japanese summary directly in chat. Use chapter timestamps from the description if present. Keep under ~400 Japanese chars unless the user asks for detail.
- **"Noteを作成" / "ノートにして"** → invoke the `notes-vault-archiver` skill conventions and write a literature note (`type: literature`) under `02.Zettelkasten/literature/` of the Notes vault. Filename pattern: `YYYY-MM-DD-<sanitized title>.md`. Use today's date.
- **"トランスクリプトを出して" / "raw transcript"** → return `/tmp/<ID>.txt` content (or paste it) without summarization.
- **No explicit ask** → default to a short Japanese summary plus an offer to save it as a note.

### Literature note frontmatter template

```yaml
---
title: "<exact video title>"
author:
  - "[[<channel name>]]"
url: "<canonical youtube URL>"
created: <today YYYY-MM-DD>
published: <upload_date YYYY-MM-DD if known>
status: "read"
type: literature
tags:
  - <topic tags>
source: youtube
duration: "約N分"
---
```

Note body skeleton:

1. `## つながり` — wikilinks to related notes (leave a placeholder if none).
2. `## 概要` — 3–5 行で全体を要約。
3. `## 章構成` — chapter timestamps from the description as a markdown table.
4. `## ハイライト` — section-by-section bullets keyed to the chapters.
5. `## 引用メモ` — 2–4 striking quotes from the transcript.
6. `## 所感 / 次アクション` — user-facing takeaways.

Filenames must avoid `|`, `/`, `:`, and other path-hostile characters — substitute ` - ` for `|` and `/`.

## Step 6 — Clean up

```bash
rm -f /tmp/<ID>.*.vtt /tmp/<ID>.txt /tmp/<ID>.info.json
```

Run this once the output is delivered. If the user is still iterating on the summary, keep `/tmp/<ID>.txt` until they confirm completion.

## Failure modes & recovery

| Symptom | Cause | Action |
| --- | --- | --- |
| `uv: command not found` after install | New `uv` not on `$PATH` | Use `~/.local/bin/uvx` absolute path; suggest adding to shell rc only if user wants it persistent |
| `No subtitles available` from yt-dlp | Captions disabled on video | Tell user, stop. Do NOT auto-fall-back to audio download/transcription. |
| VTT exists but cleaned text is empty | Unexpected VTT variant | Re-run the cleaner with `--debug` (script supports `-v` flag) and inspect the first 50 lines |
| `HTTP Error 429` or similar rate limit | yt-dlp throttled | Wait and retry; do not run repeated parallel `uvx yt-dlp` calls for the same video |
| Title contains emoji/non-ASCII | Filename safety | Strip leading emoji and trim; keep diacritics |

## What this skill does NOT do

- Download the actual audio or video.
- Transcribe via Whisper/local ASR (out of scope; ask the user before pursuing).
- Post anywhere outside the user's machine.
- Modify `~/.zshrc` / `~/.bashrc` to add `uv` to PATH unless explicitly asked.
