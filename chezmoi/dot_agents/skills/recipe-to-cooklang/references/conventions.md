# Cooklang conventions for Japanese recipes

Rules for writing `.cook` files from Japanese recipes. Independent of where the file is stored. Verified with CookCLI 0.37.

## File name and genre

- Genre (the first tag, also used as the folder by whoever stores the file): one of `和食` `洋食` `中華` `韓国` `エスニック` `お菓子` `パン` `飲み物`.
- Title: the dish name only. Drop marketing words (「簡単！」「絶品」「やみつき」「〇分で」). Keep a distinguishing qualifier when needed (`肉じゃが（圧力鍋）`).
- File name = title. Replace `/` with `・`.

## Front matter

```yaml
---
title: 親子丼
locale: ja_JP
servings: 2
tags: [和食, 丼, 鶏肉]
time: 20m
source: https://example.com/recipe/123
author: 〇〇
---
```

- `locale: ja_JP` always.
- `servings`: a number. 「2〜3人分」 → the lower number, and note the range in `description`. For recipes counted in pieces (「クッキー12枚分」), put the number in `servings` and the unit in `description` (「12枚分」). CookCLI 0.37 warns on `servings: 12個` and on `yield: 12%個`.
- `tags`: genre first, then dish type (`主菜` `副菜` `汁物` `主食` `丼` `麺` `デザート` `作り置き` `弁当`), and the main ingredient.
- `time`: only if the source states it. Use `HhMm` form (`20m`, `1h30m`).
- `source`: URL, book title, or a person (`母`). `author`: only if the source names one.
- `image`: the source's image URL if structured data provides one.
- `description`: optional one-line summary or caveat. No marketing text.

## Sections

Use sections only when they help:
- `== 下ごしらえ ==` and `== 調理 ==` for recipes with several prep steps,
- component names (`== たれ ==`, `== 生地 ==`) when parts are made separately.

## Ingredients

- Japanese names have no spaces, so **always use braces**: `@玉ねぎ{1/2%個}`, `@塩{少々}`. Without braces the name runs into the following text.
- Quantity forms:
  - fractions stay fractions: `{1/2%個}`
  - 「大さじ1と1/2」 → `{1.5%大さじ}`
  - ranges 「2〜3個」 → lower bound, range in the preparation note: `@じゃがいも{2%個}(2〜3個)`
  - 「1個（約200g）」 → source's primary unit, the other in the note: `@玉ねぎ{1%個}(約200g)`
  - 「少々」「適量」 → text quantity: `@塩{少々}`, `@サラダ油{適量}`
  - 「お好みで」 → `@七味唐辛子{適量}(お好みで)`
- Units, as written in Japanese: `g` `kg` `ml` `L` `大さじ` `小さじ` `カップ` `合` `個` `本` `枚` `片` `束` `杯` `かけ` `袋` `パック` `缶`. 大さじ・小さじ・カップ are not converted into each other; that is expected.
- Preparation goes in `()` on the first reference: `@長ねぎ{1/2%本}(小口切り)`.
- A prep-only line reads best as 「〜を用意する」: `@玉ねぎ{1/2%個}(薄切り)を用意する。`
- **Reference each ingredient with `@` once.** Later mentions are plain text (「玉ねぎを加える」). A second `@` with a quantity adds to the total.
- Use a second `@` only when it is a genuinely separate amount or preparation (e.g. 砂糖 in the sauce and 砂糖 for the dough; 玉ねぎ sliced and 玉ねぎ minced).
- Don't make an ingredient of things with no amount to buy: 「たっぷりの湯」「水（ゆでる用）」 stay plain text. Water with a stated amount is an ingredient.
- `ごはん` with an amount is an ingredient.

### Grouped seasonings (A, B, 合わせ調味料)

Japanese recipes often list 「A：醤油 大さじ2、みりん 大さじ2」. Define the group in one step, then refer to the group by name:

```cook
@醤油{2%大さじ}、@みりん{2%大さじ}、@砂糖{1%大さじ}を混ぜ合わせる（A）。

鶏肉に火が通ったらAを加え、~{3%分}煮からめる。
```

## Cookware

- Mark the main equipment once, on its first mention: `#鍋{}` `#フライパン{}` `#ボウル{}` `#電子レンジ{}` `#オーブン{}` `#炊飯器{}` `#トースター{}`. Always use `{}`.
- Don't mark generic tools (包丁, まな板, 菜箸) unless the recipe depends on them (`#落とし蓋{}` is fine).

## Timers and heat

- `~{3%分}` `~{30%秒}` `~{1%時間}`. Japanese time units are accepted by CookCLI.
- Ranges 「3〜4分」 → `~{3%分}〜4分`.
- Heat level and temperatures stay plain text: 「中火で」「180℃に予熱した#オーブン{}で~{20%分}焼く」.
- Microwave: 「#電子レンジ{}（600W）で~{2%分}加熱する」.

## Steps

- One source step → one paragraph. Separate paragraphs with a blank line.
- Rewrite in concise plain Japanese (である調でも です・ます調でもよいが、1 ファイル内で統一). Keep every quantity, time, heat level and doneness cue. Drop chatter and ads.
- Tips (コツ・ポイント) go in notes: `> 煮立たせると味噌の香りが飛ぶ。`
- Keep substitutions/variations as notes, not as extra ingredients.

## Canonical ingredient names

Use the left-hand name in recipes. When the source uses a variant, write the canonical name and report the variant, so the shopping-list configuration can list it as an alias.

| Canonical | Variants |
|---|---|
| 醤油 | しょうゆ, しょう油, 濃口醤油 |
| 薄口醤油 | うすくち醤油 |
| 味噌 | みそ |
| 酒 | 料理酒, 日本酒 |
| こしょう | 胡椒, コショウ |
| 塩こしょう | 塩コショウ, 塩胡椒 |
| 薄力粉 | 小麦粉 |
| 片栗粉 | かたくり粉 |
| だし | だし汁, 出汁 |
| 顆粒だし | 和風顆粒だし, ほんだし |
| 鶏がらスープの素 | 鶏ガラスープの素, 顆粒鶏がらスープ |
| コンソメ | 顆粒コンソメ, 固形コンソメ |
| 玉ねぎ | たまねぎ, タマネギ |
| 長ねぎ | 白ねぎ, ねぎ |
| 青ねぎ | 小ねぎ, 万能ねぎ |
| にんじん | 人参, ニンジン |
| じゃがいも | ジャガイモ, じゃが芋 |
| しょうが | 生姜, ショウガ, しょうがチューブ |
| にんにく | ニンニク, にんにくチューブ |
| 卵 | たまご, 玉子 |
| 豚こま切れ肉 | 豚こま肉, 豚小間切れ肉 |
| 鶏もも肉 | 鶏モモ肉 |

Tube vs fresh (しょうが vs しょうがチューブ) may be kept separate if the recipe depends on it; mention it in the preparation note otherwise.

