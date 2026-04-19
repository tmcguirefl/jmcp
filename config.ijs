NB. config.ijs - jmcp server configuration
NB.
NB. This is the only file that needs editing when:
NB.   - changing the port or bind address
NB.   - adding, removing, or swapping a tool group
NB.
NB. Loaded by mcp_tools.ijs via MCP_CONFIG set in server.ijs.

coclass 'jhs'

NB. -----------------------------------------------------------------------
NB. Server settings — read by server.ijs config verb and mcp_serve
MCP_PORT      =: 65001
MCP_LOCALHOST =: '0.0.0.0'

NB. -----------------------------------------------------------------------
NB. Tool group loads
NB. Each file should use its own coclass locale and define its verbs there.
NB. mcp_tool_registry.ijs must be loaded last — it builds the gerund dispatch
NB. table from whatever tool locale verbs are already defined.
load '/Users/tomdevel/jdev/jmcp/j-tools/finnhub.ijs'
load '/Users/tomdevel/jdev/jmcp/j-tools/mcp_tool_registry.ijs'

NB. -----------------------------------------------------------------------
NB. JSON Schema strings — one per tool, injected verbatim into tools/list.
NB. MCP_TOOL_REGISTRY is initialised to 0$<'' in mcp_tools.ijs before this
NB. file is loaded; just append entries here.

mcp_schema_list_news =: '{"type":"object","properties":{"category":{"type":"string","description":"News category: general, forex, crypto, or merger","default":"general"},"count":{"type":"integer","description":"Number of news items to return","default":10}},"required":[]}'

mcp_schema_get_market_data =: '{"type":"object","properties":{"stock":{"type":"string","description":"Stock ticker symbol, e.g. AAPL"}},"required":["stock"]}'

mcp_schema_get_basic_financials =: '{"type":"object","properties":{"stock":{"type":"string","description":"Stock ticker symbol, e.g. AAPL"},"metric":{"type":"string","description":"Metric group: all, price, valuation, margin, etc.","default":"all"}},"required":["stock"]}'

mcp_schema_get_recommendation_trends =: '{"type":"object","properties":{"stock":{"type":"string","description":"Stock ticker symbol, e.g. AAPL"}},"required":["stock"]}'

NB. -----------------------------------------------------------------------
NB. Tool registry entries — name ; description ; inputSchema_json
MCP_TOOL_REGISTRY =: MCP_TOOL_REGISTRY , <('list_news'                 ; 'List latest market news'                     ; mcp_schema_list_news)
MCP_TOOL_REGISTRY =: MCP_TOOL_REGISTRY , <('get_market_data'           ; 'Get market data (quote) for a given stock'   ; mcp_schema_get_market_data)
MCP_TOOL_REGISTRY =: MCP_TOOL_REGISTRY , <('get_basic_financials'      ; 'Get basic financials for a given stock'      ; mcp_schema_get_basic_financials)
MCP_TOOL_REGISTRY =: MCP_TOOL_REGISTRY , <('get_recommendation_trends' ; 'Get recommendation trends for a given stock' ; mcp_schema_get_recommendation_trends)
