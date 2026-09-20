# Agent instructions — Halation

This folder is the single source of truth for any AI coding agent working on this
repository. It is tool-neutral: `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`,
`.github/copilot-instructions.md` and `.cursor/rules/` are all thin pointers here,
so there is one set of facts to keep current rather than five that drift apart.

**Read `verified-facts.md` before changing anything that touches the model.** Most
of the cost of building this project was establishing what MiniMax H3 can actually
do. Several plausible-sounding assumptions are wrong, and that file records which
ones, with the evidence.

## Files

| File | Read it when |
|---|---|
| `project.md` | Starting anything. Architecture, invariants, where things live. |
| `verified-facts.md` | Touching the model, the catalog, formats, or timing claims. |
| `conventions.md` | Writing code. Build, lint, and how work is verified here. |
| `status.md` | Deciding what to do next. What is done, verified, and untested. |
| `roadmap/` | Picking up planned work. One file per feature. |

## Ground rules

1. **Do not state model capabilities from memory.** H3's published behaviour and
   its Apple-silicon port differ in ways that matter. Check `verified-facts.md`;
   if the answer is not there, verify it against the source and add it.
2. **Verify rather than assert.** This codebase was built by checking claims
   against the running app, the Hugging Face API and the port's own source. See
   `conventions.md` for what tools are available and what they cannot do.
3. **Do not silence a warning you have not understood.** `.swiftlint.yml`
   documents a reason for every relaxed rule. Compiler warnings have no per-line
   suppression in Swift and must be fixed properly.
4. **Say what is unverified.** Several things here could not be tested — a full
   render has never been run. `status.md` is explicit about this; keep it honest
   rather than quietly implying coverage that does not exist.
5. **Keep this folder current.** If you learn something that would have saved you
   an hour, write it down before finishing.
