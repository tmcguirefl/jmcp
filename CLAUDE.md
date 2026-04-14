# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Goal

Build a complete MCP (Model Context Protocol) server **entirely in J** using JHS (J HTTP Server)
as the HTTP frontend. Expose J tools via MCP's `tools/list` and `tools/call` methods over
Streamable HTTP transport. No Python, Node.js, or other languages.

## Related Projects

- `../jhsdev/` — General JHS development sandbox; shares the `docs/` reference vault below.

## Running J

- Start the J REPL: `jconsole`
- Load a file inside J: `load 'path/to/file.ijs'`
- Start the MCP server: `jconsole -js "load '/Users/tomdevel/jdev/jmcp/jhs-mcp-server/server.ijs'"`
- Load JHS addon: `load '~addons/ide/jhs/core.ijs'`
- Test endpoints: `curl -X POST http://localhost:65001/mcp -d '{"jsonrpc":"2.0",...}'`
- Kill the server: `pkill -f "jconsole.*server.ijs"`

## File Structure

```
jhs-mcp-server/
  server.ijs       — Entry point: loads JHS, configures port, drives request loop
  mcp_handler.ijs  — JSON-RPC 2.0 routing (initialize, tools/list, tools/call)
  mcp_tools.ijs    — Tool registry, mcp_getfield, dispatcher, result wrappers
j-tools/           — Individual J verbs, each testable standalone with jconsole
docs/              — Shared J language reference (Obsidian vault, 158 Markdown files)
                     also contains docs/JHSinfo.md (project-authored J/JHS gotchas)
```

## Development Workflow

1. Implement each tool as a J verb in `j-tools/` first — pure J, testable independently.
2. Register in `mcp_tools.ijs` with name, description, and JSON Schema `inputSchema`.
3. Handle MCP protocol methods in `mcp_handler.ijs`.
4. Wire into `server.ijs` via JHS routing.
5. Test with curl; use `python3 -m json.tool` to pretty-print responses.

## J Language Reference

**Always consult `docs/` before writing J code.** Key files:

- `docs/JHSinfo.md` — **start here**: all practical J/JHS gotchas and solutions from this project
- `docs/jdict.md` — J Primer (Hui & Iverson) — full tutorial with interactive examples
- `docs/nuvoc.md` / `docs/nuvoc1.md` / `docs/nuvoc2.md` — NuVoc: J's accessible vocabulary dictionary
- `docs/jphrases.md` — Common J idioms and phrases
- Primitive-specific files named by symbol: `docs/slash.md` (`/`), `docs/bar.md` (`|`), `docs/ampco.md` (`&:`), etc.

## Critical J/JHS Rules

Full details with examples in `docs/JHSinfo.md`. Short form:

1. **`-:` is rank-sensitive** — ravel both sides: `(,k) -: (,x)`. Literal strings are rank-0;
   pjson values are rank-1.
2. **`;` link and 2D arrays** — `scalar ; matrix` appends a row. Use `(<scalar) , <matrix`.
3. **`return.` ignores its argument** — assign first, then `return.`.
4. **End verb bodies with an explicit result variable** — avoid returning loop counters.
5. **Control structures only inside verb bodies** — not valid at script top level.
6. **`_jhs_` suffix for all cross-locale calls** — handlers run in their own locale.
7. **`htmlresponse` closes the socket** — call exactly once per request.
8. **Negative numbers in JSON** — `(": errcode) rplc '_';'-'`
9. **Right-to-left evaluation** — parenthesize sub-expressions: `(": PORT)`.
10. **`OKURL` must be a boxed list** — `OKURL =: 0$<''` before `addOKURL`.

## J Style Notes

- Prefer **tacit (point-free) style** over explicit verb definitions when idiomatic.
- J's array model is central: verbs operate on arrays; avoid scalar loops.
- All files use `coclass 'jhs'` so JHS dispatch finds handler verbs.
