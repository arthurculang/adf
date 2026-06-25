# ADF — Agentic Document Format, Version 1.0

**Status:** Draft specification
**Tagline:** One file, two readers.

The key words MUST, MUST NOT, REQUIRED, SHALL, SHALL NOT, SHOULD, SHOULD NOT,
RECOMMENDED, MAY, and OPTIONAL in this document are to be interpreted as
described in RFC 2119.

---

## 1. Goals and non-goals

### 1.1 Goals

1. **Dual readership.** A single document MUST be efficiently consumable by both
   a human-facing renderer (which cares about exact page layout) and a machine
   reader such as an LLM (which cares only about semantic content).
2. **Structural separation of content and presentation.** Content and layout
   MUST live in distinct, independently parseable layers. Extracting the full
   semantic content MUST NOT require parsing, executing, or even reading the
   layout layer.
3. **Single source of truth.** The textual content of the document MUST exist in
   exactly one place. The layout layer MUST reference content by identifier and
   MUST NOT contain a second copy of that text. This makes content/layout drift
   structurally impossible.
4. **Deterministic, fixed layout.** Given a document and a conformant renderer,
   the rendered pages MUST be reproducible to the pixel. Layout is fixed, not
   responsive: there is no reflow, no media queries, no viewport adaptation.
5. **Cheap extraction.** The canonical content stream MUST be plain UTF-8 text
   that is directly readable by a human, a `grep`, or a model with no decoding
   step beyond container extraction.
6. **Inert and safe.** The format MUST NOT support active content (scripting,
   external network fetches, launch actions). A document is data, never code.

### 1.2 Non-goals

- ADF is **not** reflowable. If you want text that adapts to a phone screen, use
  HTML. ADF deliberately trades responsiveness for fidelity, exactly as PDF does.
- ADF is **not** an interchange format for live editing collaboration (that is
  the domain of formats like `.docx`/`.odt`). ADF is a *publishing* format: the
  authored, finalized artifact.
- ADF does not standardize an authoring UI. It standardizes the bytes.

---

## 2. The two-layer model

An ADF document is composed of two normative layers plus a manifest that binds
them.

```
            ┌─────────────────────────────────────────────┐
            │                manifest.json                 │
            │  geometry · font pins · algorithm pins · hash │
            └───────────────┬───────────────┬──────────────┘
                            │               │
              references    │               │   references
            ┌───────────────▼──┐         ┌──▼───────────────┐
            │  CONTENT LAYER    │         │  LAYOUT LAYER     │
            │  content/*.adt    │◄────────┤  layout/*.adl     │
            │                   │ by node │                   │
            │  canonical text,  │   ID    │  frames, flows,   │
            │  reading order,   │         │  styles, page     │
            │  semantic blocks  │         │  placement        │
            └───────────────────┘         └───────────────────┘
              read by machines              read by renderers
```

**Invariant (normative):** The layout layer references content nodes by ID. It
MUST NOT embed the literal text of any content node. A processor MUST be able to
reproduce the entire semantic content of the document from the content layer
alone, with the layout layer absent or ignored.

The reverse also holds: the content layer MUST NOT contain positioning
coordinates, page numbers, frame geometry, or other presentation directives.
Where content needs to express *semantic* emphasis (a heading, a class such as
`.warning`), it does so abstractly; the layout layer decides what that looks
like.

---

## 3. Container

### 3.1 Packaging

An ADF document is a ZIP archive (per the standard ZIP/PKWARE specification) with
the file extension `.adf`.

The archive MUST begin with a `mimetype` entry that is:

- the **first** entry in the archive,
- **stored uncompressed** (compression method 0),
- containing the exact ASCII bytes `application/adf` with no trailing newline.

This mirrors the EPUB/ODF convention and allows the type to be sniffed from the
raw bytes: the archive starts with `PK\x03\x04`, and because `mimetype` is first
and stored, the literal string `application/adf` appears at fixed offset 38
(a 30-byte local file header + the 8-byte filename `mimetype`) without inflating
the archive. The internet media type for the whole container is
`application/vnd.adf+zip`.

> **On the `.adf` extension.** It collides with two dormant/niche formats —
> Amiga Disk File and Esri ArcInfo coverage data — neither of which co-occurs
> with agentic-document workflows. Identity therefore rides on the media type
> (`application/vnd.adf+zip`) and the magic-byte sniff above; a processor MUST
> NOT rely on the file extension alone to determine type. The media type SHOULD
> be registered, and `.adfz` is reserved as an unambiguous alternative extension.

### 3.2 Mandatory archive layout

```
document.adf
├── mimetype                  REQUIRED, first, stored
├── manifest.json             REQUIRED
├── content/
│   └── main.adt              REQUIRED (the primary content stream)
│   └── *.adt                 OPTIONAL (additional streams: notes, sidebars)
├── layout/
│   ├── pages.adl             REQUIRED (the primary layout)
│   └── *.adl                 OPTIONAL (page masters, reusable styles)
├── assets/                   OPTIONAL (fonts, images, color profiles)
└── render/                   OPTIONAL, regeneratable (glyph/render cache)
```

The `render/` directory is a non-normative cache. A conformant renderer MUST be
able to reproduce its contents from the other layers and MUST NOT trust it for
anything security- or correctness-sensitive.

### 3.3 Manifest

`manifest.json` is UTF-8 JSON. It is the entry point and the binding contract
between layers.

```json
{
  "adf": "1.0",
  "id": "urn:uuid:6f9619ff-8b86-d011-b42d-00cf4fc964ff",
  "metadata": {
    "title": "Q2 Report",
    "authors": ["Acme Research"],
    "lang": "en",
    "created": "2026-06-25",
    "modified": "2026-06-25"
  },
  "geometry": {
    "unit": "pt",
    "size": [612, 792],
    "margins": [72, 72, 72, 72]
  },
  "content": {
    "primary": "content/main.adt",
    "streams": ["content/main.adt", "content/notes.adt"]
  },
  "layout": {
    "primary": "layout/pages.adl",
    "includes": ["layout/master.adl"]
  },
  "rendering": {
    "engine": "adf-render/1.0",
    "linebreak": "knuth-plass@1",
    "hyphenation": "liang@1:en-us",
    "fonts": [
      { "family": "Source Serif", "style": "regular",
        "file": "assets/fonts/SourceSerif-Regular.otf",
        "metrics_hash": "sha256-9a1f…" }
    ]
  },
  "integrity": {
    "content/main.adt": "sha256-1b2c…",
    "layout/pages.adl": "sha256-77ef…"
  },
  "conformance": "full"
}
```

Normative requirements:

- `adf` (REQUIRED) — the spec version the document targets.
- `geometry` (REQUIRED) — default page size and margins. Individual pages MAY
  override size in the layout layer.
- `content.primary` and `layout.primary` (REQUIRED).
- `rendering.fonts[].metrics_hash` (REQUIRED for full conformance) — a hash over
  the font's glyph-advance and kerning tables. This is what makes layout
  deterministic across renderers even if a font file is re-encoded; see §6.
- `rendering.linebreak` (REQUIRED for full conformance) — the pinned
  line-breaking algorithm and version. A renderer that does not implement the
  named algorithm/version MUST refuse to claim pixel-fidelity (it MAY still
  render in degraded mode; see §8).
- `integrity` (RECOMMENDED) — SHA-256 of each referenced part. A processor
  SHOULD verify these and MUST report a mismatch.

---

## 4. Content layer (`.adt` — ADF Text)

### 4.1 Principle

The content layer is the document's meaning, in **canonical reading order**. The
order of blocks in the file **is** the logical order of the document. This single
guarantee is the thing PDFs cannot give and HTML does not promise (CSS can
reorder visually away from DOM order). In ADF, byte order = reading order, full
stop.

The content layer is a **clean, human-legible, semantic text representation** —
not a binding to one specific syntax. What ADF fixes is the *contract* (canonical
reading order, addressable nodes, no presentation), not the spelling.

The **default content profile** is `adf-text` (`.adt`): a rigorous, extensible
Markdown in the **Djot family** (cf. Djot, MyST, Pandoc Markdown) rather than bare
CommonMark. Plain CommonMark is a degenerate-but-valid `.adt`, so the cheapest
extraction is still "the file is already Markdown" — but the default profile adds
the structure that vanilla Markdown lacks and that real documents need:

- **Cross-references** to any addressable node (`[see §3](#clause-3)`), resolved
  against block IDs (§4.2). Plain Markdown cannot do this; ADF can.
- **Hierarchical / auto-numbered lists** (legal-style `1 → 1.2 → 1.2(a)(iii)`),
  not just flat `1. 2. 3.`.
- **Definition lists, attributes, and roles** — typed inline/block spans carrying
  a semantic role (`defined-term`, `citation`, …) without HTML.
- **Unambiguous nesting** — explicit block attributes instead of Markdown's
  fragile indentation rules.

This is a deliberate point on the **expressiveness ↔ token-cost ↔ legibility**
frontier: bare Markdown is cheap but too thin for schema-heavy documents; XML is
expressive but verbose and needs a parser. A Djot-grade profile keeps the
zero-decode legibility and low token cost while gaining the schema. Where even
that is insufficient (see §4.5), ADF allows a richer content profile rather than
forcing every document into one syntax.

### 4.2 Addressable nodes

Every block MAY carry an attribute list so the layout layer can target it:

```
{#intro .lead}
# Q2 Was a Good Quarter

{#rev-para}
Revenue grew 12% quarter over quarter, driven by …
```

- `{#id}` assigns a document-unique identifier (the binding handle for layout).
- `{.class}` assigns one or more semantic classes (styling hooks).
- `{key=value}` assigns arbitrary metadata (e.g. `lang=fr`).

Blocks without an explicit `{#id}` receive a **stable auto-ID** derived from
their position and a content hash, defined in Appendix A, so layout can reference
them and IDs remain stable across edits that don't touch the block.

### 4.3 Semantic blocks that PDFs destroy

`.adt` represents structure *as structure*, never as visual approximation:

- **Tables** use GFM pipe syntax and are real row/column models, not aligned
  text. An extractor gets cells, not a guess.
  ```
  {#fin-table}
  | Segment | Q1   | Q2   |
  |---------|-----:|-----:|
  | Cloud   | 4.1  | 4.6  |
  | Devices | 2.0  | 1.9  |
  ```
- **Figures** are `![alt](assets/chart.svg){#fig-rev}`. The `alt` text is part of
  the content stream and therefore part of what a model reads.
- **Footnotes / endnotes** use `[^id]` references resolved against a notes block
  or a secondary stream.
- **Math** uses `$$ … $$` (display) and `$ … $` (inline) carrying LaTeX, so the
  *expression* survives, not a picture of it.
- **Admonitions / callouts** use a fenced form `:::warning … :::` carrying a
  semantic class, with appearance deferred to layout.
- **Cross-references** (`[see §3](#clause-3)`) and **hierarchical auto-numbering**
  are first-class in the default profile, so structured documents (contracts,
  specifications, papers) keep stable, machine-resolvable internal references —
  the capability Markdown is most often faulted for lacking.

### 4.4 Multiple streams

A document MAY split content across several `.adt` files (e.g. body, margin
notes, captions). Each is independently a valid content stream. The manifest
lists them; the layout layer chooses which stream flows into which frames. The
*primary* stream defines the document's main reading order; secondary streams are
referenced from it (a footnote marker, a "see sidebar" anchor) so a machine
reader can still reconstruct a single coherent narrative.

### 4.5 Content profiles (pluggability)

The content serialization is a **parameter of the format, not its essence.** ADF's
guarantees live in the architecture — the content/layout separation (§2), the
no-duplication invariant, addressable nodes, and deterministic layout (§6) — none
of which depend on the content being Markdown. A document therefore declares a
**content profile** in the manifest:

```json
"content": {
  "primary": "content/main.adt",
  "profile": "adf-text/1.0"
}
```

- `adf-text` (default) — the Djot-grade Markdown of §4.1. Correct for the vast
  majority of documents (reports, statements, papers, decks).
- A **domain profile** — a richer vocabulary for schema-heavy verticals where even
  rich Markdown is insufficient. The canonical example is **legislation/legal**:
  statutes and contracts need defined terms, amendment structure, and
  point-in-time references that map naturally onto an established legal vocabulary
  (e.g. an Akoma Ntoso / LegalDocML-flavored stream). Such a profile MAY be used
  as the content layer **provided it still satisfies the content-layer contract**:
  it MUST be text, in canonical reading order, with addressable nodes, and MUST
  NOT carry presentation.

A conformant **content reader** (§8) MUST always be able to extract the raw text
of a stream regardless of profile; profile-aware tooling gets the richer
structure. This keeps the cheap-extraction guarantee universal while letting
demanding domains opt into more schema — without inflating the common case or
forcing a single syntax on everyone.

**v1 scope.** ADF 1.0 normatively defines exactly one profile, `adf-text/1.0`
(§4.1's Djot-grade default); the `profile` field is the forward-compatible hook
for richer vocabularies, and concrete domain profiles (e.g. a legal/Akoma Ntoso
profile) are roadmap items for later versions, not part of v1. A v1 content
reader need only handle `adf-text`, and the raw-text extraction guarantee holds
for any profile a future version adds.

> **Non-goal restated:** for *reflowable, interactive* delivery (a tiny dynamic
> web document), HTML is the right tool, and ADF can **emit** HTML as an export
> target (§ "successor, not replacement"). ADF is the *fixed-page* artifact; it
> does not try to be the reflowable one.

---

## 5. Layout layer (`.adl` — ADF Layout)

### 5.1 Principle

The layout layer is a declarative description of **fixed pages**, the **frames**
on them, and which content **flows** into those frames. It contains geometry,
style, and content *references* — never content itself.

### 5.2 Syntax

`.adl` is a small declarative language. (A JSON serialization is defined in
Appendix B for tooling; the surface syntax below is canonical for humans.)

```adl
# Pinned geometry comes from the manifest; pages may override size.

@style {
  .lead      { font: "Source Serif" 18pt; leading: 24pt; }
  body       { font: "Source Serif" 11pt; leading: 15pt; align: justify; }
  h1         { font: "Source Sans" 22pt bold; space-after: 12pt; }
  .warning   { fill: #FFF4E5; border-left: 3pt #E8A33D; pad: 8pt; }
}

@master "body-2col" {
  frame col-a at 72  72 size 226 648 ;
  frame col-b at 314 72 size 226 648 ;
  chain col-a -> col-b ;          # text threads A then B
}

page 1 {
  size 612 792 ;                  # optional per-page override
  frame title  at 72 660 size 468 64  { place #intro     style .lead   align center }
  frame byline at 72 632 size 468 20  { place #byline }
  frame fig    at 72 360 size 468 240 { place #fig-rev }
  frame lede   at 72 72  size 468 264 { flow  main from #rev-para }   # start main flow
}

page 2 uses "body-2col" {
  flow main continued ;           # the main flow resumes in this master's chain
}
```

### 5.3 Frames, placement, and flow

- A **frame** is an absolutely positioned rectangle on a page: `at x y size w h`
  in the manifest's units, origin bottom-left.
- `place #id` puts a single content node into a frame, sized to fit (used for
  titles, figures, pull quotes).
- `flow <stream> from #id` begins pouring a content stream into a frame starting
  at the given node. `flow <stream> continued` resumes that stream in subsequent
  frames/pages. `chain a -> b -> c` defines the order frames accept overflow.
  This is text threading, as in professional DTP tools.
- Because flow is explicit and ordered, the renderer performs deterministic
  line-breaking and pagination — but it never *reflows responsively*; the frames
  are fixed, so the result is fixed.

### 5.4 Style separation

All appearance lives in `@style` blocks (or included `.adl` masters), keyed by
element type and by the **semantic classes declared in the content layer**. The
content says "this paragraph is `.warning`"; the layout decides warnings are
amber with a left border. Restyling a document touches only `.adl`. This is the
"clean demarcation between style and content" requirement, enforced by giving
each its own file.

### 5.5 Overset (overflow) handling

If a flow's content does not fit its frame chain, the document is in **overset**.
A conformant authoring tool MUST resolve overset before publishing (overset is an
authoring error, not a runtime behavior — there is no responsive escape hatch). A
renderer encountering overset MUST render a visible overset marker on the last
frame and set an overset flag in its output report. Overset MUST NOT cause silent
truncation of content; the content stream remains complete regardless.

---

## 6. Deterministic rendering

This is the property that earns ADF the right to replace PDF for human-facing
documents.

### 6.1 The fidelity guarantee

> Given (a) the content bytes, (b) the layout bytes, (c) the embedded font files
> with metrics matching the manifest's `metrics_hash`, and (d) a renderer that
> implements the pinned `linebreak` and `hyphenation` algorithms at the pinned
> versions, every conformant renderer MUST produce identical page geometry:
> identical line breaks, identical glyph positions, identical pagination.

Rasterization at a given DPI MUST therefore be byte-identical up to the
well-defined antialiasing model in Appendix C.

### 6.2 Why this is achievable without freezing glyphs

PDF reaches determinism by storing the *output* of layout (each glyph's
position) and discarding the inputs. ADF reaches the same determinism by freezing
the *inputs*:

- **Page geometry** is pinned in the manifest and per page.
- **Font metrics** are pinned by hash, so advances and kerning are identical
  everywhere even if the font binary is re-subsetted.
- **The line-breaking and hyphenation algorithms** are named and versioned, so
  the function from (text, frame width, metrics) to (line breaks) is identical
  everywhere.

The difference from PDF is that the semantic content survives the process,
because layout is computed *from* it rather than replacing it.

### 6.3 No responsive behavior

A conformant renderer MUST NOT reflow content to fit a different viewport, MUST
NOT substitute fonts, and MUST NOT apply media-query-like adaptation. The page is
the size the document says it is. Viewers MAY scale the whole page uniformly
(zoom), which is a pure scalar transform and preserves fidelity.

---

## 7. Security model

- **No active content.** ADF defines no scripting, no embedded executables, no
  launch/GoToR actions, no form-submission to URLs. (PDF's support for these is a
  long-running malware vector; ADF excludes the category.)
- **No external references by default.** All assets a document needs MUST be
  inside the container. A renderer MUST NOT fetch network resources to render a
  document. A document therefore cannot phone home or track opens.
- **Integrity.** The manifest's `integrity` map lets a processor detect tampering
  of any part. Processors SHOULD verify it.
- **Signatures.** A document MAY include a detached signature at
  `META-INF/signature.json` covering the manifest (and therefore, transitively
  via the integrity hashes, every part). Verification procedure is in Appendix D.
- **Resource bounds.** Renderers SHOULD enforce limits on page count, frame
  count, and image dimensions to bound decompression-bomb risk, and MUST treat
  the `render/` cache as untrusted.

---

## 8. Conformance

Two reader profiles:

- **Content reader** (the LLM/extraction case). MUST: open the container, read
  the manifest, and emit the full content of the primary stream (and, on request,
  secondary streams) in reading order. MUST NOT be required to parse `.adl` at
  all. This profile is intentionally trivial to implement — that triviality is
  the token-cost win.
- **Layout renderer** (the human case). MUST implement everything in §§3–6 to
  claim **full** fidelity. A renderer lacking the pinned line-break/hyphenation
  algorithm MAY operate in **degraded** mode: it MUST render readable pages but
  MUST report that output is not pixel-faithful, and MUST NOT claim `full`
  conformance.

Two writer profiles, `core` (single content stream, single-column flow, no
masters) and `full` (everything), let lightweight tools emit valid ADF without
implementing the entire layout language.

**Forward compatibility.** A reader encountering an unknown `.adl` feature MUST
ignore it gracefully and continue. Critically, *content extraction never
degrades with layout-version skew*: because content lives in its own layer, any
ADF content stream from any future version remains readable by any text tool.

---

## 9. Comparison

| Capability | PDF | HTML/CSS | Markdown | DOCX/ODF | **ADF** |
|---|---|---|---|---|---|
| Pixel-fixed human layout | ✅ | ❌ (responsive) | ❌ | ⚠️ renderer-dependent | ✅ |
| Guaranteed reading order | ❌ (heuristic) | ⚠️ (CSS can reorder) | ✅ | ⚠️ | ✅ |
| Clean content/style split | ❌ | ⚠️ (DOM entangled) | ✅ | ⚠️ | ✅ structural |
| Cheap LLM extraction | ❌ (OCR/heuristics) | ⚠️ | ✅ | ⚠️ | ✅ |
| Real tables/figures/math semantics | ❌ | ✅ | ✅ | ✅ | ✅ |
| Cross-renderer determinism | ✅ | ❌ | n/a | ❌ | ✅ |
| Single source of truth (no dup text) | n/a | ❌ | ✅ | ❌ | ✅ |
| Inert / no scripting | ❌ | ❌ | ✅ | ⚠️ (macros) | ✅ |
| Accessibility by default | ❌ (needs tagging) | ⚠️ | ✅ | ⚠️ | ✅ |

ADF is the only column that is ✅ on both "pixel-fixed layout" and "cheap LLM
extraction" — which is exactly the pair the article says we currently have to
choose between.

---

## 10. Accessibility

The content stream is, by construction, a correct logical reading order with
explicit semantic structure (headings, lists, tables, figure alt text). A screen
reader consumes the same `.adt` an LLM does. Accessibility is therefore the
default state of an ADF document, not an after-the-fact tagging exercise as with
PDF.

---

## Appendix A — Stable auto-IDs

A block without an explicit `{#id}` is assigned the ID
`auto-<seq>-<h>` where `<seq>` is its zero-padded ordinal among auto-ID blocks in
its stream and `<h>` is the first 8 hex chars of `SHA-256(normalized block
text)`. Normalization: trim, collapse internal whitespace runs to one space, NFC.
Including the content hash keeps a reference valid when unrelated blocks are
inserted or removed (the ordinal shifts but tools resolve by `<h>` first, falling
back to `<seq>`).

## Appendix B — `.adl` JSON serialization

The surface `.adl` grammar maps 1:1 to a JSON form for tooling. Example of the
`page 1` block above:

```json
{ "page": 1, "size": [612, 792], "frames": [
  { "name": "title", "at": [72, 660], "size": [468, 64],
    "ops": [ { "place": "#intro", "style": ".lead", "align": "center" } ] },
  { "name": "lede", "at": [72, 72], "size": [468, 264],
    "ops": [ { "flow": "main", "from": "#rev-para" } ] }
] }
```

A processor MUST treat the two forms as equivalent.

## Appendix C — Antialiasing model

Pinned rasterization uses a defined coverage-based antialiasing model
(grayscale, gamma 2.2, 4×4 supersampling) so that "byte-identical at a given DPI"
is well defined. Sub-pixel/LCD rendering is a viewer-side option and is outside
the fidelity guarantee.

## Appendix D — Signatures

`META-INF/signature.json` carries a detached JWS over the canonical JSON form of
`manifest.json`. Because the manifest's `integrity` map covers every other part,
a valid manifest signature transitively authenticates the whole document.
Verification: (1) verify the JWS over the manifest; (2) recompute and compare
every hash in `integrity`.

---

*ADF 1.0 — draft. Comments and revisions welcome before a `fable`-era 1.0 final.*
