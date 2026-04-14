# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Goal

Build a complete MCP (Model Context Protocol) server **entirely in J** using JHS (J HTTP Server) as the HTTP frontend. Expose J tools via MCP's `tools/list` and `tools/call` methods over Streamable HTTP transport. No Python, Node.js, or other languages.

## Running J

- Start the J REPL: `jconsole`
- Load a file inside J: `load 'path/to/file.ijs'`
- Start the MCP server (once implemented): `load 'jhs-mcp-server/server.ijs'` inside jconsole
- Load JHS addon: `load'~addons/ide/jhs/core.ijs'`
- Test endpoints: `curl -X POST http://localhost:PORT/mcp -d '{"jsonrpc":"2.0",...}'`

## Planned File Structure

```
jhs-mcp-server/
  server.ijs       — Main entry: loads JHS, starts HTTP server
  mcp_handler.ijs  — JSON-RPC 2.0 routing (initialize, tools/list, tools/call, etc.)
  mcp_tools.ijs    — Tool schema registry and dispatch table (name → J verb)
j-tools/           — Individual J verbs, each testable standalone with jconsole
docs/              — Offline J language reference (158 Markdown files, Obsidian vault)
```

## Development Workflow

1. Implement each tool as a J verb in `j-tools/` first — pure J, testable independently with `jconsole`.
2. Register tools in `mcp_tools.ijs` with name, description, and JSON Schema `inputSchema`.
3. Handle MCP protocol methods in `mcp_handler.ijs`: `initialize`, `tools/list`, `tools/call`, etc.
4. Wire everything into `server.ijs` via JHS routing.

## J Language Reference

**Always consult `docs/` for correct J syntax before writing code.** Key files:

- `docs/jdict.md` — J Primer (Hui & Iverson) — full tutorial with interactive examples
- `docs/nuvoc.md` / `docs/nuvoc1.md` / `docs/nuvoc2.md` — NuVoc: J's accessible vocabulary dictionary
- `docs/jphrases.md` — Common J idioms and phrases
- `docs/jlearn.md` — Extended learning resource
- Primitive-specific files named by symbol: `docs/slash.md` (`/`), `docs/bar.md` (`|`), `docs/ampco.md` (`&:`), etc.

## J Style Notes

- Prefer **tacit (point-free) style** over explicit `{{ y ... }}` definitions when idiomatic.
- J's array model is central: verbs operate on arrays; avoid scalar loops.
- J primitives are single or two-character glyphs — consult `docs/` to verify correct spelling and rank behavior before use.
- Locales (namespaces) use `__` sigil: `verb__locale arg` or `cocreate 'name'`.
- JHS handlers are J verbs called with specific argument conventions — check `docs/` and JHS addon source for handler signatures.
