# LikeC4 DSL Reference

Shared reference for all `likec4` sub-skills. Defines DSL structural requirements, convention
rules, evaluation guidance, and sharing instructions.

---

## DSL Structural Requirements

These checks must pass before any convention rules are applied. A single failing check can cause
the VS Code plugin to flag errors across every `.c4` file in the workspace — fix blockers first.

### Element kinds

All element kinds — including `actor`, `system`, `container`, and `component` — **must** be
declared with `element <kind>` in a `specification {}` block. The VS Code plugin does not treat any
kind as automatically built-in; undeclared kinds produce "Could not resolve reference to
ElementKind" errors.

Because LikeC4 processes the entire workspace as a single project, declarations from all
`_spec.c4` files are merged. Declare each kind **once only** across the workspace — a second
declaration of the same kind causes "Duplicate element kind" errors.

A minimal `_spec.c4` for a project using the standard kinds looks like:

```c4
specification {
  element actor
  element system
  element container
  element component
}
```

### Relationship kinds

Custom relationship kinds (used with the `.kindName` dot-syntax, e.g. `customer .uses cloud`) must
be declared with `relationship <kind>` in a `specification {}` block. Undeclared relationship kinds
produce "Could not resolve reference to RelationshipKind" errors. The same workspace-merge rule
applies — declare each relationship kind once only across all `_spec.c4` files.

```c4
specification {
  relationship uses
  relationship calls
}
```

### Reserved metadata key names

These LikeC4 keywords **cannot** be used as metadata key names — they cause parse errors:

```text
source   target   link   title   description   technology
style   metadata   color   shape   icon   size   opacity
```

Use descriptive alternatives instead: `wiki`, `slack`, `email`, `adr`, `owner`, `version`, `ref`.

### Structural rules

| Rule | Check |
| --- | --- |
| STRUCT-001 | All elements are defined inside a `model { }` block — bare elements at file top level are a parse error |
| STRUCT-002 | All element kinds used (including `actor`, `system`, `container`, `component`) are declared with `element <kind>` in a `specification { }` block — no kinds are built-in |
| STRUCT-003 | All tags used (`#TAGNAME`) are declared with `tag TAGNAME` in a `specification { }` block before use |
| STRUCT-004 | LikeC4 merges all `_spec.c4` files across the workspace — each element kind and tag must be declared exactly once in total; duplicates across any two `_spec.c4` files cause "Duplicate element kind/tag" errors workspace-wide |
| STRUCT-005 | No reserved keywords used as metadata key names (see list above) |
| STRUCT-006 | All element references in views and dynamic views resolve to elements defined in the model — phantom references are errors |
| STRUCT-007 | All custom relationship kinds used with the dot-syntax (e.g. `.uses`) are declared with `relationship <kind>` in a `specification { }` block |

### Correct file structure

Every project needs a `_spec.c4` for declarations and at least one `model` file:

```c4
// _spec.c4 — project-wide declarations only
specification {
  element actor
  element system
  element container
  element component
  tag EXTERNAL
  tag DEPRECATED
}
```

```c4
// model.c4 — no specification block; all elements inside model { }
model {

  <external-service> = system '<external-service>' {
    #EXTERNAL
    description 'Project board where action items are created as cards'
    metadata {
      ref 'https://<external-service>.example'
    }
  }

}
```

---

## Convention Rules Reference

### Must Have — Critical

| Rule | Check |
| --- | --- |
| RULE-001 | Every element has a `metadata` block with at least one source link or `ref` |
| RULE-002 | All element IDs use one consistent convention (kebab-case, snake_case, or camelCase) throughout the project |
| RULE-003 | All elements and relationships have business-meaningful descriptions — not vague ("does stuff") or generic ("API") |
| RULE-004 | Project root contains `likec4.config.json` with a `name` property (multi-project only — skip for single-project repos) |

### Should Have — Important

| Rule | Check |
| --- | --- |
| RULE-101 | Single quotes for single-line values; triple single-quotes (`'''`) for multi-line; no double quotes |
| RULE-102 | Tags use `#UPPER_CASE`; elements with no applicable category are exempt |
| RULE-103 | `technology` field present on all containers and components; value is specific (`Node.js, Express`) not generic (`backend`) |
| RULE-104 | Relationship labels describe the nature of the interaction — not absent or terse |
| RULE-105 | Files follow naming pattern: `model.[name.]c4`, `view.[name.]c4`, `_spec.c4` |

### Could Have — Preferred

| Rule | Check |
| --- | --- |
| RULE-201 | Views use a limited, consistent colour palette |
| RULE-202 | Size modifiers (`xs`, `sm`, `lg`) applied to create visual hierarchy |
| RULE-203 | Related views linked with `navigateTo` |
| RULE-204 | Predicate groups used consistently across views for filtering |

---

## Evaluation Notes

- **STRUCT-001 to STRUCT-007** are pre-flight checks — always run these first; a single blocker
  can mask all other issues
- **STRUCT-004**: the `_spec.c4` for a directory is shared across all `.c4` files in that
  directory tree — one file per project directory, never one per model file
- **RULE-004 and RULE-105** are project-level checks — always evaluate against the project root,
  not the individual file
- **RULE-102** — if an element has no tags, check whether categorisation is applicable; if not,
  record as exempt not a violation
- **RULE-201 to RULE-204** only apply when view definitions are present in the files being reviewed

---

## Sharing Your Model

Display this section once per session — after the quality report (if the user declines coaching)
or after coaching completes (not both).

---

Once the model is in good shape, there are several ways to share and embed it:

**Generate a static webapp**

```bash
npx likec4 build
```

Produces a self-contained static site you can host anywhere (GitHub Pages, Cloud Storage,
Netlify). Useful for sharing with stakeholders who do not have a local LikeC4 setup.

**Serve locally for review**

```bash
npx likec4 serve
```

Starts a local development server with live reload. Useful for reviewing the model during
authoring.

**Embed views in markdown documentation**

The community plugin `mkdocs-likec4` lets you embed diagram views directly in markdown using
fenced code blocks. Verify it is maintained and compatible with your docs setup before adopting.

**References**

- LikeC4 CLI: <https://likec4.dev/tooling/cli/>
- LikeC4 DSL reference: <https://likec4.dev/dsl/>
- LikeC4 validation guide: <https://likec4.dev/guides/validate-your-model/>
