#!/usr/bin/env python3
"""Clean YouTube auto-generated VTT into readable plain text.

YouTube auto-VTT emits karaoke-style rolling captions: each word gets its own
cue with inline <HH:MM:SS.mmm> timestamps, and the previous line is repeated
on the next cue for paint-on. Raw output is ~10x longer than the actual text.

Usage:
    clean_vtt.py path/to/file.vtt [more.vtt ...] [-v]

Output goes to stdout. Reads multiple files in order and concatenates.
"""
from __future__ import annotations

import argparse
import re
import sys
from html import unescape
from pathlib import Path

TIMESTAMP_TAG = re.compile(r"<\d{2}:\d{2}:\d{2}\.\d{3}>")
C_TAG = re.compile(r"</?c[^>]*>")
CUE_TIMING = re.compile(r"\d{2}:\d{2}:\d{2}\.\d{3}\s+-->")
HEADER_PREFIX = ("WEBVTT", "Kind:", "Language:", "NOTE", "STYLE", "REGION")


def clean_file(path: Path, verbose: bool = False) -> list[str]:
    text = path.read_text(encoding="utf-8", errors="replace")
    out: list[str] = []
    for raw in text.split("\n"):
        ln = raw.rstrip()
        if not ln.strip():
            continue
        if CUE_TIMING.search(ln):
            continue
        if ln.startswith(HEADER_PREFIX):
            continue
        ln = TIMESTAMP_TAG.sub("", ln)
        ln = C_TAG.sub("", ln)
        ln = unescape(ln).strip()
        if not ln:
            continue
        out.append(ln)

    if verbose:
        print(f"# {path.name}: {len(out)} raw lines", file=sys.stderr)

    final: list[str] = []
    for line in out:
        if final:
            prev = final[-1]
            if line == prev:
                continue
            if line in prev or prev.endswith(line):
                continue
            if prev in line:
                final[-1] = line
                continue
        final.append(line)
    return final


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("paths", nargs="+", type=Path, help="VTT files (glob-expanded by shell)")
    ap.add_argument("-v", "--verbose", action="store_true", help="Print per-file stats to stderr")
    args = ap.parse_args()

    all_lines: list[str] = []
    for p in args.paths:
        if not p.exists():
            print(f"clean_vtt: missing {p}", file=sys.stderr)
            return 2
        all_lines.extend(clean_file(p, verbose=args.verbose))

    sys.stdout.write("\n".join(all_lines))
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
