---
name: place-recipe
description: Store one or more Cooklang `.cook` files on the home cook server (M1 Mac mini, `ssh homeserver`, `~/Services/cook/recipes`) — duplicate check, genre folder, shopping-list `aisle.conf` update, upload, and verification. Use after `recipe-to-cooklang`, or whenever the user wants existing `.cook` files added to their recipe collection ("サーバーに置いて", "レシピ集に追加").
---

# Place Recipe

Stores validated `.cook` files in the recipe collection served by `cook server`. Writing the files is the `recipe-to-cooklang` skill's job; this skill only places them.

## Where things live

- Source of truth: `homeserver:~/Services/cook/recipes/` (clone of the private repo `shsw228/Recipes`). The cook server reads it live; no restart needed.
- GitHub is only a backup: a container on the Mac mini commits and pushes every 10 minutes. **Never** edit the local clone at `~/Developer/ghq/github.com/shsw228/Recipes` and never push to it.
- Layout: `<genre>/<title>.cook`, and `config/aisle.conf` for shopping-list categories.
- Web UI: `http://homeservermac-mini-m1.local:9080/recipe/<genre>/<title>` (over Tailscale: `homeservermac-mini-m1`).

## Step 1 — Load the collection

```bash
ssh homeserver 'cd ~/Services/cook/recipes && find . -name "*.cook" -not -path "./.git/*" | sort && echo "=====" && cat config/aisle.conf'
```

## Step 2 — Decide where each file goes

- **Folder**: the file's first tag (genre). Reuse an existing folder; create a new one only when the genre has none.
- **Duplicates**: if the same or a near-same title exists anywhere, ask whether to overwrite, save as a variant (e.g. `肉じゃが（圧力鍋）`, which also changes `title` in the file), or skip.
- **Ingredient names**: if the file uses a name that an existing `aisle.conf` line lists as an alias, rename it in the file to that line's canonical (first) name. Re-run `cook doctor validate` on the file after any edit.

## Step 3 — Update aisle.conf

Work on a scratch copy laid out like the server:

```
<scratch>/recipes/config/aisle.conf   ← server copy
<scratch>/recipes/<genre>/<title>.cook
```

Run `cook doctor aisle` in `<scratch>/recipes`, then for every missing ingredient:
- add it under a fitting category, one ingredient per line as `canonical|alias|alias`,
- append the `canonical ← variant` pairs reported by `recipe-to-cooklang` as aliases on the canonical line.

Categories in use: `野菜` `肉` `卵・豆腐` `米・主食` `調味料` `その他`. Add these when needed: `魚介` `乳製品` `乾物` `果物` `冷凍` `缶詰・瓶詰`. Re-run `cook doctor aisle` until nothing is missing.

## Step 4 — Confirm with the user

Show the target paths, the `aisle.conf` additions, and any renames or duplicate decisions. Upload only after the user agrees. If the user already said to save without asking, skip the confirmation but report the same items afterwards.

## Step 5 — Upload

```bash
ssh homeserver 'mkdir -p ~/Services/cook/recipes/<genre>'
scp "<scratch>/recipes/<genre>/<title>.cook" "homeserver:Services/cook/recipes/<genre>/"
```

- Never overwrite an existing file unless the user chose to in Step 2.
- For `aisle.conf`: re-fetch the server copy first and compare it with the copy from Step 1 (the Web UI can edit it). If it changed, merge your additions into the new copy. Then upload with `scp`.

## Step 6 — Verify and report

```bash
ssh homeserver 'curl -s localhost:9080/api/recipes' | grep -c "<title>"
```

Reply in Japanese with the Web UI link for each recipe, the `aisle.conf` changes, and a note that GitHub gets the change within about 10 minutes via the automatic backup.
