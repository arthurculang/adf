# Why ADF is cheap to feed to a model

This is the entire reason ADF exists, so it deserves its own page with real
numbers. The claim is narrow and defensible: **extracting the content of an ADF
document costs a small fraction of the tokens that extracting the same content
from a PDF costs, at higher fidelity.**

## Where PDF tokens go

A PDF is glyphs at coordinates. To feed one to a model you pick one of:

1. **Render pages to images, use a vision model.** You pay image tokens per
   page. For a typical full page at a usable resolution, that lands in the
   ballpark of ~1,000–3,000 tokens *per page* depending on the provider's tiling
   model — before the model has reasoned about anything. A 20-page report is
   ~20k–60k tokens of pure input just to look at it.
2. **Extract text with a PDF library, then send the text.** Cheaper in tokens,
   but the extractor has to *reconstruct* reading order, columns, and tables from
   positioned glyphs. Multi-column layouts interleave, tables collapse into
   ragged text, headers/footers bleed into the body. You then often spend *more*
   model tokens cleaning up the mess, and accuracy on tables/figures is poor.

Either way you are paying — in tokens, in latency, or in errors — to recover
structure that the author had and threw away.

## Where ADF tokens go

You read one file: `content/main.adt`. It is already clean Markdown in correct
reading order, with real tables and figure alt text. The token cost is
approximately:

```
tokens ≈ characters_of_actual_content / ~4
```

That is the floor for representing the document's meaning at all. There is no
layout overhead, because layout is in a different file you never open. There is
no reconstruction, because reading order is the byte order. There is no OCR,
because the text was never rasterized.

## Worked example: the `quarterly-report` in this repo

The example document is a two-page report: masthead, two prose sections, a
four-row financial table, a chart, a callout, and an outlook.

| Path | What you'd send a model | Approx. input tokens |
|------|-------------------------|----------------------|
| As **PDF**, vision, 2 pages | two page images | ~2,000–6,000 |
| As **PDF**, text-extracted | de-interleaved text + cleanup | ~700 + cleanup + table errors |
| As **ADF** (`content/main.adt`) | 1,266 bytes of clean Markdown | **~320** |

The `.adt` is 1,266 bytes / 198 words; at ~4 chars/token that's roughly **320
tokens**, and they are *all signal* — the table arrives as a table, the figure as
its alt text, the callout as labeled prose, every block in reading order. Against
the vision path that is roughly a **6×–18× reduction**, and against text
extraction it's cheaper *and* structurally correct.

> Numbers are order-of-magnitude estimates; exact image-token counts vary by
> provider tiling model and resolution. The point is the ratio and the
> fidelity, not a specific integer.

## Two structural wins beyond raw count

1. **Selective extraction.** Content blocks are addressable by ID and section.
   An agent that needs only the financials reads `#fin-table`; one that needs the
   outlook reads `#outlook-*`. A PDF forces you to ingest whole pages because the
   bytes aren't addressable by meaning. ADF lets an agent pay for the paragraph
   it wants, not the document it's in.
2. **No accuracy tax.** The cheapest PDF path (text extraction) is also the most
   error-prone on exactly the high-value structures — tables, multi-column
   bodies, math. ADF removes the tradeoff: the cheap path *is* the accurate path,
   because the structure was preserved at authoring time instead of being guessed
   at read time.

## The macro argument

The article's framing is abundance vs. scarcity: either make compute so cheap
that brute-forcing PDFs stops mattering, or stop wasting the compute. ADF is the
second path, and it's the cheap one to build — no new silicon, just a format that
keeps the content the author already had. Every document published as ADF instead
of PDF is a permanent reduction in the tokens every future reader spends on it.
The savings compound across every open, by every agent, forever.
