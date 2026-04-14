## Evaluation Criteria

**1. Structure completeness** — must contain all five core sections:

- **Purpose** — What is this? What problem does it solve? (one to two sentences, leads with value)
- **Audience** — Who is it for? (explicit or clearly implied)
- **Getting started** — Prerequisites stated *before* install steps; copy-pasteable commands
- **Usage** — Common patterns with real, working examples
- **Contributing or Help** — Link to contribution guide, issue tracker, or contact

Flag each missing section as **Critical**.

**2. Opening impact** — the first 200 words determine whether a reader continues:

- Does it lead with the value proposition, not the technology?
- Is there a working example within the first screen of content?
- Does it avoid starting with badges, CI status, or a table of contents?

**3. Prerequisite clarity** — prerequisites must appear *before* the first install command, not embedded within steps. Flag any install or setup instruction that assumes knowledge not yet stated.

**4. Reading age — target: Flesch-Kincaid Grade 9 (UK Year 9)**

- **Sentence length**: flag sentences exceeding 25 words
- **Passive voice**: flag individual passive constructions inline — prefer active voice. Note: individual passive-voice flags here are sentence-level findings; the document-level passive-voice rate is handled separately in criterion 6. Do not double-count the same sentence in both the per-sentence list (criterion 4) and the aggregate rate finding (criterion 6) — if a sentence is already cited as a criterion-4 finding, omit it from the criterion-6 evidence list but still count it toward the overall rate.
- **Nominalisation**: flag noun-heavy phrasing ("the utilisation of X" → "using X")
- **Jargon**: flag technical terms or acronyms not defined on first use
- **Nested clauses**: flag sentences with more than two levels of subordination

For each flagged item, suggest a simpler rewrite.

**5. Code block completeness**:

- Every fenced code block must have a language identifier
- No placeholder ellipsis inside executable blocks (e.g., `... your config here`)
- Commands must be copy-pasteable without modification

**6. Active vs passive voice** — count sentences matching the pattern `(is|are|was|were|been|being)\s+\w+ed` (passive constructions). Count total sentences (end with `.`, `?`, or `!`). If passive count ÷ total sentence count > 0.20, flag it as a document-level pattern with the exact count and percentage. **Precedence rule:** criterion 4 takes priority for individual sentence rewrites; criterion 6 is for document-level rate reporting only. Do not repeat individual-sentence fixes from criterion 4 under criterion 6.

**7. UK English consistency** — flag common US spellings:

| US | UK |
| --- | --- |
| color | colour |
| organize | organise |
| license (noun) | licence |
| behavior | behaviour |
| center | centre |
| fulfill | fulfil |

**8. Link hygiene**:

- Bare URLs must be wrapped in `<>` or formatted as `[text](url)`
- Flag relative links that could be broken (note but do not verify)

**9. Badge overload** — flag if more than three shield badges appear before any substantive content.