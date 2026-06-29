# Example: Acme Q2 Report

A small but complete two-page ADF document, in source form.

> **Status — illustrative.** This example demonstrates the *structure* (the
> content/layout split, addressable nodes, threaded two-column flow) and the
> cheap content-extraction path. It is **not** a pixel-fidelity render fixture:
> the fonts are referenced but not embedded, and the manifest's font
> `metrics_hash` values are placeholders. A full-fidelity fixture depends on the
> pinned font-metric and line-break definitions (a spec roadmap item). The
> `content`/`layout` integrity hashes that `build.sh` writes, however, are real
> and are checked in CI.

## Files

| File | Layer | What it is |
|------|-------|------------|
| `mimetype` | container | The literal bytes `application/adf` (no newline), first/stored in the ZIP. |
| `manifest.json` | binding | Metadata, page geometry, font + algorithm pins, integrity hashes. |
| `content/main.adt` | **content** | The words. Clean Markdown. **This is what an LLM reads.** |
| `layout/pages.adl` | **layout** | Where the words go on two fixed pages. References content by ID; contains no text. |
| `assets/` | resources | Fonts and the revenue chart (placeholders here). |

## Build the container

```bash
./build.sh          # produces ../quarterly-report.adf
```

## See the two-readers property for yourself

A human renderer composes both layers into a pixel-fixed two-page document.

A machine reader needs only one file:

```bash
unzip -p ../quarterly-report.adf content/main.adt
```

That command returns the entire semantic document — headings, the real table,
the figure's alt text, the callout — in correct reading order, as plain text,
with zero layout noise to pay tokens for. There is no OCR step, no column
de-interleaving, no reading-order guesswork. That is the whole point.

## Things to notice

1. **No duplicated text.** Open `layout/pages.adl` — it mentions `#fin-table`
   and `#rev-para`, but the table's numbers and the prose live *only* in
   `content/main.adt`. One source of truth.
2. **Author controls placement.** The table and the guidance callout are
   `place`d at explicit coordinates; the body prose `flow`s through a threaded
   two-column chain on page 2. Total layout control, exactly like a PDF.
3. **Restyling never touches content.** Change every font and color by editing
   only `pages.adl`. The content stream — the thing machines and screen readers
   consume — is untouched.
