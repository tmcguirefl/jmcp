# jmcp — MCP Server in Pure J

A [Model Context Protocol](https://modelcontextprotocol.io/) (MCP) server written entirely in the **J programming language**, using **JHS** (J HTTP Server) as the HTTP frontend. No Python, Node.js, or other runtimes required.

Exposes J verbs as MCP tools over the Streamable HTTP transport, making them callable by any MCP-compatible client (Claude Desktop, VS Code extensions, etc.).

---

## Architecture

```
MCP Client (Claude Desktop, etc.)
        │  POST /mcp  (JSON-RPC 2.0)
        ▼
  JHS HTTP Server  (port 65001)
        │
        ▼
  jev_post_raw_mcp_          ← mcp_handler.ijs: protocol router
        │
        ├── initialize        → session management, capability negotiation
        ├── tools/list        → mcp_tools_json (registry → JSON)
        └── tools/call        → mcp_dispatch → j-tools/ verb → result
```

### File structure

```
jhs-mcp-server/
  server.ijs       — Entry point: loads JHS, sets port, drives the request loop
  mcp_handler.ijs  — JSON-RPC 2.0 routing (initialize, tools/list, tools/call)
  mcp_tools.ijs    — Tool registry, mcp_getfield, dispatcher, result wrappers

j-tools/           — One .ijs file per tool; each is independently testable
docs/              — J language reference vault (NuVoc, J Dictionary, JHS notes)
```

---

## How It Works

### Server startup (`server.ijs`)

`server.ijs` loads JHS, overrides the port and `AUTO` flag via a `config` verb (the correct JHS hook for post-`configdefault` overrides), pre-initialises `OKURL` as a boxed list so `/mcp` is reachable without a login redirect, then drives the request loop manually:

```j
NB. server.ijs (simplified)
load '~addons/ide/jhs/core.ijs'
coclass 'jhs'

config =: 3 : 0
  AUTO =: 0       NB. no browser launch
  PORT =: 65001
)

load '~/jdev/jmcp/jhs-mcp-server/mcp_tools.ijs'
load '~/jdev/jmcp/jhs-mcp-server/mcp_handler.ijs'

OKURL =: 0$<''
addOKURL 'mcp'

mcp_serve =: 3 : 0
  jhscfg''
  IFJHS_z_ =: 1
  LOCALHOST =: '0.0.0.0'
  SKSERVER_jhs_ =: _1
  r =. dobind''
  ...
  while. 1 do.
    getdata''
    if. (1=RAW) *. 'mcp'-:URL do.
      ".('jev_post_raw_mcp_ ''''')
    end.
  end.
)
mcp_serve''
```

### Protocol handler (`mcp_handler.ijs`)

`jev_post_raw_mcp_` is the JHS handler verb for `POST /mcp`. It decodes the JSON-RPC body with `dec_pjson_`, dispatches on `method`, and replies with `htmlresponse`. Session IDs are generated and validated on every non-`initialize` call.

### Tool registry (`mcp_tools.ijs`)

Tools are registered as a boxed list of triples `(name ; description ; inputSchema_json)`. `mcp_tools_json` serialises the registry to a JSON array for `tools/list`. `mcp_dispatch` routes `tools/call` to the matching J verb.

`mcp_getfield` extracts a named field from a `dec_pjson_`-decoded object (a boxed 2-column matrix of key–value rows):

```j
mcp_getfield =: 4 : 0
  r =. ''
  i =. 0
  nx =. , x          NB. ravel: pjson keys are rank-1; literals are rank-0
  while. i < # y do.
    row =. i { y
    k =. , > 0 { row
    if. k -: nx do.
      r =. > 1 { row
      return.
    end.
    i =. >: i
  end.
  r
)
```

---

## Running the Server

```sh
jconsole -js "load '~/jdev/jmcp/jhs-mcp-server/server.ijs'"
```

The server prints:

```
jmcp MCP server listening on http://0.0.0.0:65001/mcp
```

Kill it with:

```sh
pkill -f "jconsole.*server.ijs"
```

### Quick smoke test

```sh
# 1. initialize — get a session ID
curl -s -D - -X POST http://localhost:65001/mcp \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{}}}'

# 2. tools/list (replace SESSION_ID with the Mcp-Session-Id from step 1)
curl -s -X POST http://localhost:65001/mcp \
  -H 'Content-Type: application/json' \
  -H 'Mcp-Session-Id: SESSION_ID' \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' | python3 -m json.tool
```

---

## Adding a New Tool — Worked Examples

### Example 1 — `add`: sum two numbers

**`j-tools/add.ijs`**

```j
NB. add.ijs - Add two numbers
NB. Standalone test:  load 'j-tools/add.ijs'  then  mcp_add 3;5  NB. gives 8

coclass 'jhs'

NB. y is a;b (boxed list of two numbers)
NB. @: is infinite-rank atop: unbox each element then sum
mcp_add =: +/ @: >
```

The verb is purely tacit. `>` unboxes the argument list, giving a numeric array; `+/` inserts `+` between all elements.

Test it standalone before wiring it in:

```sh
jconsole
   load 'j-tools/add.ijs'
   mcp_add 3;5
8
```

### Example 2 — `multiply`: product of two numbers

**`j-tools/multiply.ijs`**

```j
NB. multiply.ijs - Multiply two numbers
NB. Standalone test:  load 'j-tools/multiply.ijs'  then  mcp_multiply 6;7  NB. gives 42

coclass 'jhs'

NB. y is a;b (boxed list of two numbers)
NB. @: is infinite-rank atop: unbox each element then take product
mcp_multiply =: */ @: >
```

Same pattern: `>` unboxes, `*/` inserts `*`.

```sh
jconsole
   load 'j-tools/multiply.ijs'
   mcp_multiply 6;7
42
```

### Registering the tools in `mcp_tools.ijs`

Once the verbs work standalone, register them:

```j
NB. 1. Load the implementation files
load '~/jdev/jmcp/j-tools/add.ijs'
load '~/jdev/jmcp/j-tools/multiply.ijs'

NB. 2. Define JSON Schema strings for each tool
mcp_schema_add =: '{"type":"object","properties":{"a":{"type":"number"},"b":{"type":"number"}},"required":["a","b"]}'
mcp_schema_multiply =: '{"type":"object","properties":{"a":{"type":"number"},"b":{"type":"number"}},"required":["a","b"]}'

NB. 3. Add entries to the registry
MCP_TOOL_REGISTRY =: MCP_TOOL_REGISTRY , <('add'      ; 'Add two numbers'      ; mcp_schema_add)
MCP_TOOL_REGISTRY =: MCP_TOOL_REGISTRY , <('multiply' ; 'Multiply two numbers' ; mcp_schema_multiply)
```

### Dispatching in `mcp_dispatch`

Add a `case.` for each tool in the `select.` block:

```j
case. 'add' do.
  a =. 'a' mcp_getfield y
  b =. 'b' mcp_getfield y
  ": mcp_add a ; b

case. 'multiply' do.
  a =. 'a' mcp_getfield y
  b =. 'b' mcp_getfield y
  ": mcp_multiply a ; b
```

`mcp_dispatch` must return a **string** (the result is wrapped by `mcp_ok_result` and sent as JSON text). Use `":` to convert a numeric result.

### End-to-end test

```sh
curl -s -X POST http://localhost:65001/mcp \
  -H 'Content-Type: application/json' \
  -H 'Mcp-Session-Id: SESSION_ID' \
  -d '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"add","arguments":{"a":3,"b":5}}}' \
  | python3 -m json.tool
```

Expected result field: `"8"`.

---

## Current Tools

| Tool | Description |
|------|-------------|
| `list_news` | List latest market news (Finnhub) |
| `get_market_data` | Real-time quote for a stock ticker |
| `get_basic_financials` | Key financial metrics for a stock |
| `get_recommendation_trends` | Analyst recommendation trends for a stock |

---

## Key J/JHS Rules

| Rule | Why it matters |
|------|----------------|
| Ravel before `-:` comparison: `(,k) -: (,nx)` | Literal strings are rank-0; `dec_pjson_` strings are rank-1 — bare `-:` will fail |
| `return.` ignores its argument — assign first | `r =. value ⋄ return.` not `return. value` |
| End verb bodies with an explicit result variable | Avoids returning loop counters |
| `_jhs_` suffix for all cross-locale calls | Handlers run in a `mcp` locale; `jhs`-locale globals need the explicit suffix |
| `htmlresponse` closes the socket — call exactly once | Calling twice crashes the request |
| Negative numbers in JSON: `(": n) rplc '_';'-'` | J prints `_32601`; JSON requires `-32601` |
| `OKURL =: 0$<''` before `addOKURL` | `addOKURL` requires a boxed list; the JHS default is a plain string |

Full details and examples: `docs/JHSinfo.md`.

---

## Requirements

- [J 9.x](https://www.jsoftware.com/#/README) with the `ide/jhs` and `convert/pjson` addons installed
- No other runtime dependencies
