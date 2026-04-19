# Finnhub MCP Tool Specification

This document describes how the Finnhub market-data tools were translated from a Python FastMCP implementation into pure J running under the jmcp MCP server. It is intended as a **template and reference** for specifying new tool groups — either additional Finnhub endpoints or entirely new API integrations.

---

## Original Python Specification

The tools were originally defined using Python's FastMCP library (`mcpfinnhub.py`):

```python
from fastmcp import FastMCP
from finnhub import Client
import os

finnhub_client = Client(api_key=os.getenv("FINNHUB_API_KEY"))
mcp = FastMCP("mcp-finnhub")

@mcp.tool(name="list_news", description="List all latest market news")
def list_news(category: str = "general", count: int = 10):
    news = finnhub_client.general_news(category)
    return news[:count]

@mcp.tool(name="get_market_data", description="Get market data for a given stock")
def get_market_data(stock: str):
    return finnhub_client.quote(stock)

@mcp.tool(name="get_basic_financials", description="Get basic financials for a given stock")
def get_basic_financials(stock: str, metric: str = "all"):
    return finnhub_client.company_basic_financials(stock, metric)

@mcp.tool(name="get_recommendation_trends", description="Get recommendation trends for a given stock")
def get_recommendation_trends(stock: str):
    return finnhub_client.recommendation_trends(stock)
```

Each `@mcp.tool` decorator registers the function name, description, and parameter types automatically. The J implementation replicates each of these pieces explicitly across three files.

---

## J Implementation Overview

A tool group in J requires changes in three places:

| File | What goes there |
|------|----------------|
| `j-tools/<locale>.ijs` | Tool verbs in an isolated locale; API key; HTTP helper |
| `j-tools/mcp_tool_registry.ijs` | Adapter verbs; dispatch table entries |
| `jhs-mcp-server/mcp_tools.ijs` | Load statement; JSON schema strings; registry entries |

The mapping from Python to J for the Finnhub group:

| Python concept | J equivalent |
|---------------|-------------|
| `os.getenv("FINNHUB_API_KEY")` | `APIKEY =: read_apikey''` in `coclass 'finnhub'` |
| `finnhub_client = Client(api_key=...)` | `fetch` verb using `gethttp_wgethttp_` with `APIKEY` appended |
| `@mcp.tool(name=..., description=...)` | Entry in `MCP_TOOL_REGISTRY` in `mcp_tools.ijs` |
| Function parameter types → JSON Schema | `mcp_schema_*` string in `mcp_tools.ijs` |
| Function body | Tool verb in `finnhub.ijs` |
| FastMCP routing | Adapter verb in `mcp_tool_registry.ijs` + agenda `@.` dispatch |

---

## File 1 — Tool locale: `j-tools/finnhub.ijs`

Each tool group lives in its own named J locale. This isolates globals (like `APIKEY`) and addon state from the `jhs` server locale.

```j
coclass 'finnhub'

require '~addons/web/gethttp/gethttp.ijs'

NB. 2!:5 returns numeric 0 when the env var is unset, not ''.
NB. read_apikey type-checks before calling dltb.
read_apikey =: 3 : 0
  r =. 2!:5 'FINNHUB_API_KEY'
  if. 2 = 3!:0 r do. dltb r else. '' end.
)
APIKEY =: read_apikey''

NB. fetch - GET a URL, return the response body as a string.
NB. Guards against missing APIKEY before making any HTTP call.
fetch =: 3 : 0
  if. 0 = # APIKEY do. 'FINNHUB_API_KEY not set' return. end.
  'stdout' gethttp_wgethttp_ y
)

NB. list_news
NB. Python: finnhub_client.general_news(category)[:count]
NB. y is category;count  (e.g. 'general';10)
list_news =: 3 : 0
  'category count' =. 2 {. (y , 'general' ; 10)
  category =. dltb ": > category
  count    =. > count
  fetch 'https://finnhub.io/api/v1/news?category=' , category , '&token=' , APIKEY
)

NB. get_market_data
NB. Python: finnhub_client.quote(stock)
NB. y is stock symbol string  (e.g. 'AAPL')
get_market_data =: 3 : 0
  fetch 'https://finnhub.io/api/v1/quote?symbol=' , (dltb ": y) , '&token=' , APIKEY
)

NB. get_basic_financials
NB. Python: finnhub_client.company_basic_financials(stock, metric)
NB. y is stock;metric  (e.g. 'AAPL';'all')
get_basic_financials =: 3 : 0
  'stock metric' =. 2 {. (y , 'UNKNOWN' ; 'all')
  stock  =. dltb ": > stock
  metric =. dltb ": > metric
  fetch 'https://finnhub.io/api/v1/stock/metric?symbol=' , stock , '&metric=' , metric , '&token=' , APIKEY
)

NB. get_recommendation_trends
NB. Python: finnhub_client.recommendation_trends(stock)
NB. y is stock symbol string  (e.g. 'AAPL')
get_recommendation_trends =: 3 : 0
  fetch 'https://finnhub.io/api/v1/stock/recommendation?symbol=' , (dltb ": y) , '&token=' , APIKEY
)
```

### Design notes

- **`coclass 'finnhub'`** — all verbs and globals are scoped to the `finnhub` locale. Callers outside this locale use the explicit suffix form, e.g. `get_market_data_finnhub_`.
- **`require` instead of `load`** — `require` is idempotent; the addon is loaded only once regardless of how many files call it.
- **`read_apikey` verb** — `2!:5` (read environment variable) returns numeric `0` when the variable is not set, not an empty string. A verb body is required to type-check with `3!:0` (type is `2` for character) before calling `dltb`. Control structures are not valid at script top level in J.
- **`fetch` guard** — checking `0 = # APIKEY` in `fetch` means every tool benefits from a single guard. If the key is missing the function returns a plain error string rather than crashing.
- **Argument conventions** — monadic verbs (`3 : 0`); `y` is either a string (single-parameter tools) or a boxed list `a;b` (multi-parameter tools). Defaults are supplied by appending them to `y` before destructuring: `2 {. (y , default1 ; default2)`.
- **Return value** — raw JSON string from the Finnhub REST API, passed back as-is. The MCP layer wraps it in a content object.
- **Standalone testability** — every verb can be called directly in `jconsole` after `load`:
  ```
  load '~/jdev/jmcp/j-tools/finnhub.ijs'
  get_market_data_finnhub_ 'AAPL'
  ```

---

## File 2 — Dispatch table: `j-tools/mcp_tool_registry.ijs`

This file connects MCP `tools/call` requests to the locale verbs. It uses J's **agenda** conjunction `@.` — a data-driven dispatch that replaces a `select./case.` block.

```j
coclass 'jhs'

NB. --- Adapter verbs ---
NB. One per tool. Must be 4:0 (dyadic) because agenda always calls dyadically.
NB. x = tool name (ignored except in mcp_run_unknown_tool)
NB. y = decoded pjson args object (boxed n×2 matrix of key/value pairs)
NB. Return value must be a string — mcp_ok_result wraps it as JSON text.

mcp_run_list_news =: 4 : 0
  category =. 'category' mcp_getfield_jhs_ y
  count    =. 'count'    mcp_getfield_jhs_ y
  if. 0 = # category do. category =. 'general' end.
  if. 0 = # ": count  do. count    =. 10        end.
  list_news_finnhub_ category ; count
)

mcp_run_get_market_data =: 4 : 0
  get_market_data_finnhub_ 'stock' mcp_getfield_jhs_ y
)

mcp_run_get_basic_financials =: 4 : 0
  stock  =. 'stock'  mcp_getfield_jhs_ y
  metric =. 'metric' mcp_getfield_jhs_ y
  if. 0 = # metric do. metric =. 'all' end.
  get_basic_financials_finnhub_ stock ; metric
)

mcp_run_get_recommendation_trends =: 4 : 0
  get_recommendation_trends_finnhub_ 'stock' mcp_getfield_jhs_ y
)

NB. Fallback — x carries the bad tool name for the error message
mcp_run_unknown_tool =: 4 : 0
  'unknown tool: ' , x assert 0
)

NB. --- Dispatch table ---
NB. MCP_DISPATCH_NAMES has N entries. i. on an N-element list returns N on a miss,
NB. which routes to mcp_run_unknown_tool at position N in the gerund list.

MCP_DISPATCH_NAMES =: 'list_news' ; 'get_market_data' ; 'get_basic_financials' ; 'get_recommendation_trends'

MCP_DISPATCH_GERUNDS =: mcp_run_list_news`mcp_run_get_market_data`mcp_run_get_basic_financials`mcp_run_get_recommendation_trends`mcp_run_unknown_tool

NB. Selector: map tool-name x to an integer index into MCP_DISPATCH_GERUNDS
mcp_tool_selector =: 4 : 0
  MCP_DISPATCH_NAMES_jhs_ i. < , x
)

NB. mcp_dispatch: single tacit verb — agenda selects and calls the right adapter
mcp_dispatch =: MCP_DISPATCH_GERUNDS @. mcp_tool_selector
```

### Design notes

- **Adapter verbs are `4 : 0` (dyadic)** — J's agenda `@.` always calls the selected gerund with both `x` (tool name) and `y` (args). Monadic `3 : 0` definitions raise a valence error at call time.
- **`mcp_getfield_jhs_`** — extracts a named field from the decoded pjson args object. Returns `''` if the field is absent. Use this to read every MCP argument.
- **Default values** — since `mcp_getfield` returns `''` for absent optional fields, check emptiness explicitly: `if. 0 = # fieldvalue do. fieldvalue =. default end.` For numeric fields, `": count` converts to string first so `#` counts characters not magnitude.
- **`_jhs_` suffix** — adapter verbs run in the `jhs` locale but are called via the agenda from various contexts. Explicitly suffix all cross-locale references: `mcp_getfield_jhs_`, `list_news_finnhub_`, `MCP_DISPATCH_NAMES_jhs_`.
- **Gerund list with `` ` ``** — `` u`v`w `` is J's Tie conjunction; it forms a flat boxed list of verb representations (gerunds). The list must be defined after all adapter verbs are defined. `mcp_run_unknown_tool` is always the last entry.
- **Miss routing** — `MCP_DISPATCH_NAMES i. <,x` returns `# MCP_DISPATCH_NAMES` (4) when the name is not found. `mcp_run_unknown_tool` sits at index 4 in the 5-element gerund list, so unknown tools are handled automatically without any explicit check.
- **Return value** — adapter verbs must return a **character string**. Numeric results must be converted with `":`. The string is passed to `mcp_ok_result` which wraps it as `{"content":[{"type":"text","text":"..."}],"isError":false}`.

---

## File 3 — Server wiring: `jhs-mcp-server/mcp_tools.ijs`

```j
NB. Load the tool locale (runs coclass 'finnhub', reads APIKEY, requires gethttp)
load '/Users/tomdevel/jdev/jmcp/j-tools/finnhub.ijs'

NB. JSON Schema strings — one per tool, pre-encoded to avoid nested pjson complexity.
NB. These drive the tools/list response seen by MCP clients.
mcp_schema_list_news =: '{"type":"object","properties":{"category":{"type":"string","description":"News category: general, forex, crypto, or merger","default":"general"},"count":{"type":"integer","description":"Number of news items to return","default":10}},"required":[]}'

mcp_schema_get_market_data =: '{"type":"object","properties":{"stock":{"type":"string","description":"Stock ticker symbol, e.g. AAPL"}},"required":["stock"]}'

mcp_schema_get_basic_financials =: '{"type":"object","properties":{"stock":{"type":"string","description":"Stock ticker symbol, e.g. AAPL"},"metric":{"type":"string","description":"Metric group: all, price, valuation, margin, etc.","default":"all"}},"required":["stock"]}'

mcp_schema_get_recommendation_trends =: '{"type":"object","properties":{"stock":{"type":"string","description":"Stock ticker symbol, e.g. AAPL"}},"required":["stock"]}'

NB. Tool registry entries — name ; description ; schema
MCP_TOOL_REGISTRY =: MCP_TOOL_REGISTRY , <('list_news'                 ; 'List latest market news'                     ; mcp_schema_list_news)
MCP_TOOL_REGISTRY =: MCP_TOOL_REGISTRY , <('get_market_data'           ; 'Get market data (quote) for a given stock'   ; mcp_schema_get_market_data)
MCP_TOOL_REGISTRY =: MCP_TOOL_REGISTRY , <('get_basic_financials'      ; 'Get basic financials for a given stock'      ; mcp_schema_get_basic_financials)
MCP_TOOL_REGISTRY =: MCP_TOOL_REGISTRY , <('get_recommendation_trends' ; 'Get recommendation trends for a given stock' ; mcp_schema_get_recommendation_trends)
```

### Design notes

- **Load order** — the locale file must be loaded before `mcp_tool_registry.ijs`, which must be loaded before any registry lookup. `mcp_tools.ijs` controls this sequence.
- **JSON Schema strings** — hand-written JSON strings stored as J character vectors. The schema is embedded verbatim into the `tools/list` response. `"required":[]` for optional parameters; `"required":["field"]` for mandatory ones.
- **`MCP_TOOL_REGISTRY`** — a boxed list of triples `(name ; description ; schema_json)`. The name must match the corresponding entry in `MCP_DISPATCH_NAMES` in `mcp_tool_registry.ijs` exactly, though the two structures are independent (one serves `tools/list`, the other `tools/call`).

---

## Finnhub REST Endpoints Reference

| Tool | HTTP endpoint | Parameters |
|------|--------------|------------|
| `list_news` | `GET /api/v1/news` | `category` (string), `token` |
| `get_market_data` | `GET /api/v1/quote` | `symbol` (string), `token` |
| `get_basic_financials` | `GET /api/v1/stock/metric` | `symbol`, `metric` (string), `token` |
| `get_recommendation_trends` | `GET /api/v1/stock/recommendation` | `symbol` (string), `token` |

All endpoints return a JSON string directly from the Finnhub API. The J implementation passes this raw JSON back to the MCP client without parsing or reshaping it.

---

## Adding a New Finnhub Tool

To add, for example, `get_company_profile` (`GET /api/v1/stock/profile2?symbol=SYMBOL`):

**1. Add the verb to `j-tools/finnhub.ijs`:**
```j
NB. get_company_profile
NB. y is stock symbol string
get_company_profile =: 3 : 0
  fetch 'https://finnhub.io/api/v1/stock/profile2?symbol=' , (dltb ": y) , '&token=' , APIKEY
)
```

**2. Add an adapter verb to `j-tools/mcp_tool_registry.ijs`:**
```j
mcp_run_get_company_profile =: 4 : 0
  get_company_profile_finnhub_ 'stock' mcp_getfield_jhs_ y
)
```

Then extend the dispatch table (keeping `mcp_run_unknown_tool` last):
```j
MCP_DISPATCH_NAMES =: MCP_DISPATCH_NAMES , < 'get_company_profile'

MCP_DISPATCH_GERUNDS =: mcp_run_list_news`mcp_run_get_market_data`mcp_run_get_basic_financials`mcp_run_get_recommendation_trends`mcp_run_get_company_profile`mcp_run_unknown_tool
```

**3. Add schema and registry entry to `jhs-mcp-server/mcp_tools.ijs`:**
```j
mcp_schema_get_company_profile =: '{"type":"object","properties":{"stock":{"type":"string","description":"Stock ticker symbol, e.g. AAPL"}},"required":["stock"]}'

MCP_TOOL_REGISTRY =: MCP_TOOL_REGISTRY , <('get_company_profile' ; 'Get company profile and general information' ; mcp_schema_get_company_profile)
```

**4. Test standalone, then restart the server:**
```sh
jconsole
   load '~/jdev/jmcp/j-tools/finnhub.ijs'
   get_company_profile_finnhub_ 'AAPL'
```

---

## Template for a New Tool Group

To add an entirely new API (not Finnhub), follow the same three-file pattern:

```
j-tools/<newgroup>.ijs          coclass '<newgroup>'
                                require (HTTP addon or other)
                                APIKEY or credentials read via read_<cred> verb
                                fetch or equivalent HTTP helper
                                one monadic verb per tool

j-tools/mcp_tool_registry.ijs  one mcp_run_<toolname> =: 4 : 0 adapter per tool
                                extend MCP_DISPATCH_NAMES
                                extend MCP_DISPATCH_GERUNDS (before mcp_run_unknown_tool)

jhs-mcp-server/mcp_tools.ijs   load '<newgroup>.ijs'
                                mcp_schema_<toolname> =: '...'  per tool
                                MCP_TOOL_REGISTRY entries
```
