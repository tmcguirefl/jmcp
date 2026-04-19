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
  jev_post_raw_mcp_              ← mcp_handler.ijs: protocol router
        │
        ├── initialize            → session management, capability negotiation
        ├── tools/list            → mcp_tools_json (MCP_TOOL_REGISTRY → JSON)
        └── tools/call
                │
                ▼
          mcp_dispatch            ← mcp_tool_registry.ijs: agenda (@.) dispatch
          MCP_DISPATCH_GERUNDS    ← gerund list built with `
          @. mcp_tool_selector    ← i. lookup into MCP_DISPATCH_NAMES
                │
                ▼
          adapter verb            ← extracts fields from pjson args, calls tool
                │
                ▼
          tool locale verb        ← e.g. get_market_data_finnhub_
```

### File structure

```
jhs-mcp-server/
  server.ijs            — Entry point: loads JHS, sets port, drives request loop
  mcp_handler.ijs       — JSON-RPC 2.0 routing (initialize, tools/list, tools/call)
  mcp_tools.ijs         — Tool registry (MCP_TOOL_REGISTRY), mcp_getfield,
                          result wrappers, loads tool locales

j-tools/
  finnhub.ijs           — coclass 'finnhub': all Finnhub tools, APIKEY, fetch helper
  mcp_tool_registry.ijs — Agenda dispatch table: adapter verbs, MCP_DISPATCH_NAMES,
                          MCP_DISPATCH_GERUNDS, mcp_dispatch

docs/                   — J language reference vault (NuVoc, J Dictionary, JHS notes)
```

---

## Prerequisites

### J 9.x

Install from [jsoftware.com](https://www.jsoftware.com/#/README). The `ide/jhs` and `convert/pjson` addons must be present (included in the standard J distribution).

### Finnhub API key

The Finnhub tools require a free API key from [finnhub.io](https://finnhub.io).

1. Register at [finnhub.io/register](https://finnhub.io/register) — the free tier covers all tools in this server.
2. Copy your key from the Finnhub dashboard.
3. Set it in your shell environment **before** starting the server:

```sh
# Add to ~/.zshrc or ~/.bash_profile for persistence
export FINNHUB_API_KEY=your_key_here
```

Then reload your shell or run `source ~/.zshrc`. Verify with:

```sh
echo $FINNHUB_API_KEY
```

The server reads the key once at load time into the isolated `finnhub` locale. If the variable is unset, all Finnhub tool calls return `"FINNHUB_API_KEY not set"` as a graceful error rather than crashing.

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
# 1. initialize — returns session ID in Mcp-Session-Id header
curl -s -D - -X POST http://localhost:65001/mcp \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{}}}'

# 2. tools/list (replace SESSION_ID with the value from step 1)
curl -s -X POST http://localhost:65001/mcp \
  -H 'Content-Type: application/json' \
  -H 'Mcp-Session-Id: SESSION_ID' \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' | python3 -m json.tool

# 3. call a tool
curl -s -X POST http://localhost:65001/mcp \
  -H 'Content-Type: application/json' \
  -H 'Mcp-Session-Id: SESSION_ID' \
  -d '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"get_market_data","arguments":{"stock":"AAPL"}}}' \
  | python3 -m json.tool
```

---

## How It Works

### Protocol handler (`mcp_handler.ijs`)

`jev_post_raw_mcp_` is the JHS handler verb for every `POST /mcp`. It decodes the JSON-RPC body with `dec_pjson_`, checks for a session ID header, dispatches on `method`, and sends the response via `htmlresponse`.

### Field lookup (`mcp_getfield` in `mcp_tools.ijs`)

`dec_pjson_` returns a boxed n×2 matrix — rows are key/value pairs. `mcp_getfield` uses dyadic `i.` on the key column for a loopless lookup:

```j
mcp_getfield =: 4 : 0
  keys =. 0 {"1 y       NB. boxed key column from the n×2 pjson matrix
  idx  =. keys i. < x   NB. i. uses match on boxes; returns #keys on miss
  if. idx < # keys do. > 1 { idx { y else. '' end.
)
```

### Agenda dispatch (`mcp_tool_registry.ijs`)

`mcp_dispatch` uses J's **agenda** conjunction `@.` to replace a hard-coded `select./case.` block with a data-driven lookup. The dispatch table is two parallel structures kept in `j-tools/mcp_tool_registry.ijs`:

```j
MCP_DISPATCH_NAMES =: 'list_news' ; 'get_market_data' ; 'get_basic_financials' ; 'get_recommendation_trends'

MCP_DISPATCH_GERUNDS =: mcp_run_list_news`mcp_run_get_market_data`mcp_run_get_basic_financials`mcp_run_get_recommendation_trends`mcp_run_unknown_tool
```

The selector maps a tool name to an integer index. `i.` on a 4-element list returns `4` on a miss, automatically routing to the `mcp_run_unknown_tool` fallback at index 4:

```j
mcp_tool_selector =: 4 : 0
  MCP_DISPATCH_NAMES_jhs_ i. < , x
)

mcp_dispatch =: MCP_DISPATCH_GERUNDS @. mcp_tool_selector
```

When `x mcp_dispatch y` is called, agenda:
1. Calls `x mcp_tool_selector y` → integer index
2. Selects the corresponding gerund from `MCP_DISPATCH_GERUNDS`
3. Calls the selected verb with the **original** `x` and `y`

Adapter verbs are `4 : 0` (dyadic) because agenda always calls dyadically. They extract their own fields from `y` (the pjson args object) and forward to the tool locale:

```j
mcp_run_get_market_data =: 4 : 0
  get_market_data_finnhub_ 'stock' mcp_getfield_jhs_ y
)
```

### Finnhub tool locale (`j-tools/finnhub.ijs`)

All Finnhub tools live in a single file under `coclass 'finnhub'`. This isolates `APIKEY` and the `gethttp` addon from the `jhs` locale, and ensures initialization runs exactly once:

```j
coclass 'finnhub'
require '~addons/web/gethttp/gethttp.ijs'

read_apikey =: 3 : 0
  r =. 2!:5 'FINNHUB_API_KEY'
  if. 2 = 3!:0 r do. dltb r else. '' end.
)
APIKEY =: read_apikey''

fetch =: 3 : 0
  if. 0 = # APIKEY do. 'FINNHUB_API_KEY not set' return. end.
  'stdout' gethttp_wgethttp_ y
)

get_market_data =: 3 : 0
  fetch 'https://finnhub.io/api/v1/quote?symbol=' , (dltb ": y) , '&token=' , APIKEY
)
```

Standalone test (no server needed):

```sh
FINNHUB_API_KEY=your_key jconsole
   load '~/jdev/jmcp/j-tools/finnhub.ijs'
   get_market_data_finnhub_ 'AAPL'
```

---

## Adding a New Tool — Worked Examples

The pattern for any new tool group is:

1. Create a locale file in `j-tools/` — one file per logical group, `coclass 'mylocale'`
2. Add adapter verbs and register in `j-tools/mcp_tool_registry.ijs`
3. Add schema and registry entry in `jhs-mcp-server/mcp_tools.ijs`

### Example — `add` and `multiply`

#### Step 1 — Tool verbs in their own locale (`j-tools/math.ijs`)

```j
NB. math.ijs - Simple arithmetic tools
NB. Standalone test:
NB.   load '~/jdev/jmcp/j-tools/math.ijs'
NB.   add_math_ 3 ; 5     NB. gives 8
NB.   multiply_math_ 6 ; 7  NB. gives 42

coclass 'math'

NB. y is a;b (boxed pair of numbers)
add      =: +/ @: >
multiply =: */ @: >
```

`>` unboxes the pair into a numeric array; `+/` or `*/` inserts the operator across it. Test standalone:

```sh
jconsole
   load '~/jdev/jmcp/j-tools/math.ijs'
   add_math_ 3 ; 5
8
   multiply_math_ 6 ; 7
42
```

#### Step 2 — Add adapter verbs to `mcp_tool_registry.ijs`

```j
NB. Adapter verbs (4:0 — agenda calls dyadically; x=tool name, y=args object)
mcp_run_add =: 4 : 0
  a =. 'a' mcp_getfield_jhs_ y
  b =. 'b' mcp_getfield_jhs_ y
  ": add_math_ a ; b
)

mcp_run_multiply =: 4 : 0
  a =. 'a' mcp_getfield_jhs_ y
  b =. 'b' mcp_getfield_jhs_ y
  ": multiply_math_ a ; b
)
```

Adapter verbs must return a **string** — `mcp_ok_result` wraps it as JSON text. Use `":` to convert numeric results.

Then extend the dispatch table (append before `mcp_run_unknown_tool`):

```j
MCP_DISPATCH_NAMES =: MCP_DISPATCH_NAMES , 'add' ; 'multiply'

MCP_DISPATCH_GERUNDS =: mcp_run_list_news`...`mcp_run_add`mcp_run_multiply`mcp_run_unknown_tool
```

#### Step 3 — Register in `mcp_tools.ijs`

```j
NB. Load the math locale
load '~/jdev/jmcp/j-tools/math.ijs'

NB. JSON schemas
mcp_schema_add      =: '{"type":"object","properties":{"a":{"type":"number"},"b":{"type":"number"}},"required":["a","b"]}'
mcp_schema_multiply =: '{"type":"object","properties":{"a":{"type":"number"},"b":{"type":"number"}},"required":["a","b"]}'

NB. Registry entries
MCP_TOOL_REGISTRY =: MCP_TOOL_REGISTRY , <('add'      ; 'Add two numbers'      ; mcp_schema_add)
MCP_TOOL_REGISTRY =: MCP_TOOL_REGISTRY , <('multiply' ; 'Multiply two numbers' ; mcp_schema_multiply)
```

#### Step 4 — End-to-end test

```sh
curl -s -X POST http://localhost:65001/mcp \
  -H 'Content-Type: application/json' \
  -H 'Mcp-Session-Id: SESSION_ID' \
  -d '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"add","arguments":{"a":3,"b":5}}}' \
  | python3 -m json.tool
```

Expected `result.content[0].text`: `"8"`.

---

## Current Tools

All tools require `FINNHUB_API_KEY` to be set in the environment (see [Prerequisites](#prerequisites)).

| Tool | Description |
|------|-------------|
| `list_news` | Latest market news — categories: `general`, `forex`, `crypto`, `merger` |
| `get_market_data` | Real-time quote for a stock ticker (open, close, high, low, etc.) |
| `get_basic_financials` | Key financial metrics — metric groups: `all`, `price`, `valuation`, `margin` |
| `get_recommendation_trends` | Analyst buy/hold/sell recommendation trends by period |

---

## Key J/JHS Rules

| Rule | Why it matters |
|------|----------------|
| `return.` ignores its argument — assign first | `r =. value ⋄ return.` not `return. value` |
| End verb bodies with an explicit result variable | Avoids returning loop counters |
| `_jhs_` suffix for all cross-locale calls | Handlers run in a `mcp` locale (copath: z only); jhs-locale verbs need the explicit suffix |
| Adapter verbs must be `4 : 0` (dyadic) | Agenda `@.` always calls the selected gerund dyadically |
| `htmlresponse` closes the socket — call exactly once | Calling twice crashes the request |
| Negative numbers in JSON: `(": n) rplc '_';'-'` | J prints `_32601`; JSON requires `-32601` |
| `OKURL =: 0$<''` before `addOKURL` | `addOKURL` requires a boxed list; the JHS default is a plain string |
| `2!:5` returns numeric `0` for unset env vars | Type-check with `3!:0` before treating as a string |
| Control structures only inside verb bodies | `if./while./try.` are not valid at script top level — wrap in a `3 : 0` verb |

Full details and examples: `docs/JHSinfo.md`.

---

## Requirements

- [J 9.x](https://www.jsoftware.com/#/README) with the `ide/jhs` and `convert/pjson` addons installed
- A free [Finnhub API key](https://finnhub.io/register) for the Finnhub tools
- No other runtime dependencies
