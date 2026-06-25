# ADF — the Agentic Document Format

> One file, two readers. Pixel-perfect for humans, plain text for machines.

ADF is a document format designed for the world we actually live in now, where
**every document is read twice**: once by a person who cares about layout, and
once by a language model that just wants the words. PDF was built for the first
reader and is hostile to the second. HTML serves the second but can't promise
the first. ADF serves both, on purpose, by keeping them in separate layers of
the same file.

## Why this exists

[The token belt-tightening is coming for PDFs.](https://gizmodo.com/the-token-belt-tightening-is-coming-for-pdfs-2000777063)
As companies meter AI spend, the cost of shoving PDFs through models has become
a line item. A PDF stores a document as **glyphs frozen at (x, y) coordinates** —
the semantic content (reading order, columns, tables, headings) is *destroyed* at
authoring time. To get it back, a model has to OCR or heuristically re-derive the
structure. That is exactly the expensive, error-prone work that burns tokens.

The fix is not a bigger model or a Dyson sphere. It's a format that never throws
the content away in the first place.

## The idea (credit: Milad)

> Preserve the best of PDFs — total control over formatting and page layout for
> humans — with a clean demarcation between style and content, so content can be
> extracted efficiently by LLMs, à la Markdown. Like HTML, but without responsive
> rendering.

ADF takes that literally:

| Layer | Audience | What it is | How it's read |
|-------|----------|------------|---------------|
| **Content** (`.adt`) | LLMs, search, a11y | A canonical, clean text stream — a Djot-grade Markdown by default, swappable to a richer vocabulary for schema-heavy domains. The *source of truth* for what the document says. | Read the file. That's it. |
| **Layout** (`.adl`) | Human renderers | A declarative, absolute-positioning instruction set that *references content nodes by ID* and places them on fixed pages. | Compose with content, render to fixed pixels. |

The two never duplicate each other. Layout points at content by ID; it contains
**no text of its own**. So there is one source of truth and zero drift, and the
separation is *structural* — you literally cannot read prose out of the layout
layer, and you cannot read positioning out of the content layer.

## The trick that makes it work

PDF gets visual fidelity by freezing the **output** of layout (glyphs at
coordinates) and discarding the inputs. ADF gets the *same* fidelity by freezing
the **inputs**: page geometry, frame boxes, embedded font metrics, and a pinned
line-breaking algorithm. Given those, every conformant renderer produces
byte-identical pages — "total control over layout" — while the semantic content
rides along untouched.

"Like HTML but without responsive rendering" is precise: frames are fixed, there
is no reflow, no media queries, no font fallback. A page is a page.

## What's in this repo

- **[`spec/ADF-1.0-SPECIFICATION.md`](spec/ADF-1.0-SPECIFICATION.md)** — the normative specification.
- **[`docs/token-economics.md`](docs/token-economics.md)** — why ADF is cheap to feed to a model, with worked numbers.
- **[`examples/quarterly-report/`](examples/quarterly-report/)** — a real ADF document in source form, plus `build.sh` to pack it into a `.adf` container.
- **[`docs/design-rationale.md`](docs/design-rationale.md)** — the decisions and the alternatives that were rejected.

## The 30-second mental model

```
report.adf  (a ZIP container)
├── mimetype                 → application/adf
├── manifest.json            → metadata, page geometry, font + algorithm pins, integrity hashes
├── content/main.adt         → the words, as clean readable text (Markdown for most docs). THIS is what an LLM reads.
├── layout/pages.adl         → where the words go on fixed pages. THIS is what a renderer reads.
└── assets/                  → subsetted fonts, images
```

An agent that wants the content does `unzip -p report.adf content/main.adt` and
pays for prose tokens only. A human opens it and sees a pixel-perfect page. Same
file. No reconciliation step, no OCR, no guessing.

## License

ADF is dual-licensed: the **specification and documentation** (`spec/`, `docs/`,
this `README.md`) under [CC-BY-4.0](LICENSES/CC-BY-4.0.txt), and the **example and
any tooling** (`examples/`) under [Apache-2.0](LICENSES/Apache-2.0.txt) — see
[`LICENSE`](LICENSE) for the full split. Anyone may read, quote, and implement the
spec; the Apache-2.0 grant additionally covers this repository's code.

---

*Naming: **ADF** = Agentic Document Format. Proposed in a group chat the night the
article went around; the heart on the message is load-bearing.*
