# Design rationale

The decisions behind ADF, and the alternatives that were considered and rejected.

## The central bet: freeze layout *inputs*, not layout *outputs*

Every fixed-layout format faces the same question: how do you guarantee the page
looks identical everywhere? PDF answers by storing the **output** of layout —
each glyph at its final coordinate — and discarding the inputs (the text stream,
the reading order, the table structure). That guarantees fidelity but destroys
semantics, which is the root cause of the token problem.

ADF answers by storing the **inputs** and pinning them: page geometry, frame
boxes, font metrics (by hash), and the line-break/hyphenation algorithm (by
version). A renderer recomputes the same layout everywhere because the function
and all its inputs are fixed. Fidelity is preserved *and* the semantic content
survives, because layout is derived from content rather than replacing it.

This is the whole design in one sentence. Everything else follows.

## Why two files instead of one cleverly-marked-up file

We could have put content and layout in a single file with markup separating
them (the HTML/CSS approach: one DOM, styling layered on). Rejected, because:

- **Separation by convention is not separation.** In HTML, CSS can reorder,
  hide, and inject content, so the visual order can diverge from the DOM order
  and "the text" is not a well-defined extraction. We want the separation to be
  *structural*: a content reader that never opens the layout file literally
  cannot be misled by it.
- **Cheap extraction wants a cheap target.** "Read this one small text file" is a
  trivial, fast, robust operation. "Parse this document, build a tree, apply a
  cascade, then figure out what the text is" is not. The token win depends on the
  extraction target being dumb-simple.

So: two layers, bound by a manifest, with a hard invariant that layout holds no
text.

## Why a ZIP container

Proven by EPUB, ODF, and DOCX. A container lets the content stream be a
standalone, directly-extractable file (`unzip -p`), lets fonts and images travel
with the document for the no-external-references security property, and gives a
natural home for the manifest and signatures. The `mimetype`-first-stored trick
gives byte-level type sniffing for free.

The cost is that an `.adf` isn't human-readable in a text editor without
unzipping. Accepted: the *content* is trivially extractable, which is what
matters, and authoring tools hide the container anyway.

## Why a Markdown-family content layer — and why it's pluggable

The content layer is the document's meaning, and we want it both *cheap for models
to read* and *expressive enough for real documents*. Those pull in opposite
directions, so the choice is a point on a frontier:

- **Bare Markdown (CommonMark)** is the cheapest, most legible thing a model can
  read — but it's genuinely too thin for schema-heavy documents. You can't do
  cross-references, hierarchical/auto-numbered clauses, defined terms, or
  unambiguous nesting. The fair critique "Markdown doesn't work for legislation"
  is correct of *plain* Markdown.
- **XML (DocBook/DITA/JATS)** is expressive enough but verbose, and you need a
  parser to get the text back — which forfeits the zero-decode extraction that is
  ADF's whole point.

So the default is neither extreme: a **Djot-grade Markdown** (cf. Djot — built by
the CommonMark author specifically to be unambiguous and extensible — and MyST /
Pandoc Markdown). It keeps Markdown's legibility and low token cost while adding
cross-references, hierarchical numbering, attributes, roles, and definition
structures. Plain CommonMark remains a valid (if degenerate) content stream, so
"I have a Markdown file" still works.

Crucially, the serialization is a **parameter, not the essence.** ADF's value is
the content/layout separation and deterministic layout — none of which depend on
Markdown. So schema-heavy verticals (legislation, contracts) may use a richer
*content profile* (e.g. an Akoma Ntoso-flavored stream) as long as it honors the
content-layer contract: text, canonical reading order, addressable nodes, no
presentation. We don't inflate the common case to serve the hard case; we let the
hard case opt in.

We still add only what the two-layer model needs — stable block IDs and semantic
classes/roles — and resist presentation in the content stream; anything that
smells like appearance belongs in `.adl`.

> One honest boundary: for *reflowable, interactive* delivery (a tiny dynamic web
> document — e.g. "send HTML instead of a PDF"), HTML is the better tool. ADF is
> the fixed-page artifact and emits HTML as an export target rather than trying to
> be reflowable itself.

## Why a declarative layout language with explicit flow

Layout needs absolute frames (for "total control") *and* text threading (so long
prose can pour across columns and pages without the author hand-placing every
line). This is the InDesign/QuarkXPress model, and it's the right one: `place`
for things you pin exactly, `flow`/`chain` for prose that threads. We made flow
**explicit and ordered** rather than inferred, because inference is where
reading-order ambiguity creeps back in — and unambiguous order is the property we
are most trying to protect.

## Why no responsive behavior — on purpose

"Like HTML but without responsive rendering" is not a missing feature, it's the
thesis. Responsiveness is fundamentally incompatible with "the author has total
control over the page," because a responsive document has no single page to
control. ADF is the fixed-layout publishing artifact; if you want reflow, that's
a different document and HTML already does it well. Trying to be both is how you
get neither, which is roughly the state of fixed-layout EPUB.

## Why no scripting, ever

PDF's support for embedded JavaScript and launch actions has produced two decades
of malware. The feature buys little for a *document* and costs enormous security
surface. ADF excludes the entire category: a document is inert data. This also
keeps the format analyzable — a static checker can fully reason about an ADF file
because there's no code to run.

## How documents get authored

You hand-author *content*; you do not hand-author *layout*. Block IDs are
auto-assigned (Appendix A) and you type one only to pin a block; fixed layout is
produced by tooling — templates, code that emits `.adl`, or eventually a visual
editor — exactly as nobody hand-writes a PDF byte stream.

That ordering is deliberate. The first authoring surfaces are **programmatic /
AI-generation** (code and models emit the layout) and **converters** to and from
existing formats, because neither needs a human-facing editor to exist and both
meet documents where they already are. A full visual editor is the most
capital-heavy piece and is deferred until adoption justifies it — building it
first is the classic chicken-and-egg trap. (For *reflowable* delivery, ADF emits
HTML rather than growing an editor for a job HTML already does well.)

## What we explicitly deferred to a later version

- **Reflowable annexes.** A future version might allow an optional reflowable
  presentation *in addition to* the fixed one, sharing the same content layer.
  The content/layout split makes this clean to add later without touching v1.
- **Incremental update / revisions.** PDF-style append-only revisions could be
  layered on the container; not needed for v1 publishing.
- **Rich interactive forms.** Out of scope by design (see "no scripting"); a
  constrained, declarative form model could come later.

## The one risk we're accepting

A format is only as good as its adoption. ADF's bet is that the token-cost
pressure described in the article is a strong enough forcing function that
publishers will care about a format whose documents are cheap for agents to read.
The design hedges this by making the *content* layer plain Markdown — so even if
ADF-the-container never wins, the content extraction story degrades gracefully to
"it was Markdown all along."
