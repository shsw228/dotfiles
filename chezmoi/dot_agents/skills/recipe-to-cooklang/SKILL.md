---
name: recipe-to-cooklang
description: Convert a recipe from a URL (especially Japanese sites such as クックパッド, クラシル, DELISH KITCHEN, Nadia, 白ごはん.com, みんなのきょうの料理, or a YouTube video whose description holds the recipe), pasted text, a photo/screenshot of a cookbook, or a spoken-style description into a validated Cooklang `.cook` file. Only writes the file; storing it on the cook server is the `place-recipe` skill. Use when the user wants a recipe turned into Cooklang ("cooklang にして", "レシピを書き起こして"), and as the first half of adding a recipe ("レシピ追加", "このレシピ入れて"), followed by `place-recipe`.
---

# Recipe to Cooklang

Turns any recipe source into one `.cook` file that follows [references/conventions.md](references/conventions.md), and checks it with the local CookCLI (`cook`). `cook import` is not used: it does not understand Japanese recipe sites.

This skill does not know or touch any storage location. It hands over a file path.

## Step 1 — Get the source

- **URL**: first try structured data, which keeps exact quantities:
  ```bash
  curl -sL -A "Mozilla/5.0" "<URL>" | python3 -c 'import sys,re
  for m in re.findall(r"<script[^>]*application/ld\+json[^>]*>(.*?)</script>", sys.stdin.read(), re.S):
      print(m.strip()[:20000]); print("-----")'
  ```
  Use the `Recipe` object (`name`, `recipeYield`, `recipeIngredient`, `recipeInstructions`, `totalTime`, `author`, `image`). If there is none, or the page is blocked/JS-rendered, fall back to WebFetch and ask it for the full ingredient list with exact quantities and every step verbatim. If both fail, ask the user to paste the text or a screenshot.
- **YouTube** (`youtube.com/watch`, `youtu.be`, `/shorts/`): the recipe is usually in the description. Fetch it with `uv` (never install `yt-dlp` globally):
  ```bash
  uvx --python 3.12 yt-dlp --skip-download --print "%(title)s" --print "%(uploader)s" --print "%(thumbnail)s" --print "%(description)s" "<URL>" 2>/dev/null
  ```
  Use the uploader as `author`, the thumbnail as `image`, the URL as `source`. If the description has no ingredient list, tell the user and ask before transcribing from the video's subtitles.
- **Photo / screenshot**: read it with the Read tool. Transcribe quantities exactly; if anything is illegible, ask instead of guessing.
- **Pasted text or free description**: use as is. For family recipes without a source, ask only for what is missing and matters (servings, key quantities).
- Never invent quantities. Keep 「少々」「適量」 as text quantities.

## Step 2 — Write the file

Read [references/conventions.md](references/conventions.md) and write `<out>/<title>.cook`, where `<out>` is the directory the user named, or else a fresh directory in the scratchpad.

## Step 3 — Validate

```bash
cd <out>
cook doctor validate
cook recipe "<title>.cook"
```

Compare the `cook recipe` output with the source:
- every source ingredient appears once with the right quantity (a doubled amount means an ingredient was `@`-referenced twice),
- no ingredient name swallowed following text (a missing `{}`),
- steps read naturally in Japanese and none is lost.

Fix and re-run until `cook doctor validate` reports no errors or warnings.

## Step 4 — Hand over

Show the user, concisely:
- the file path,
- the full `.cook` content,
- the genre (first tag),
- 表記ゆれ you normalized, as `canonical ← variant` pairs,
- anything you inferred or could not read.

If the user's request was to add or save the recipe, continue with the `place-recipe` skill, passing the file path and the normalized variants. Otherwise stop here.
