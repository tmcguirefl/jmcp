NB. mcp_tools.ijs - Tool registry and dispatcher
NB. Defines: mcp_getfield, MCP_TOOL_REGISTRY, mcp_tools_json, mcp_dispatch
NB. mcp_ok_result, mcp_err_result
NB. Loaded by server.ijs before mcp_handler.ijs

coclass 'jhs'

NB. Load all Finnhub tools (coclass 'finnhub' — isolated locale, single APIKEY read)
load '/Users/tomdevel/jdev/jmcp/j-tools/finnhub.ijs'

NB. Load agenda-based dispatch table (defines mcp_dispatch)
load '/Users/tomdevel/jdev/jmcp/j-tools/mcp_tool_registry.ijs'

NB. -----------------------------------------------------------------------
NB. mcp_getfield - look up a key in a pjson-decoded object
NB. pjson dec_object returns a boxed 2-col matrix; each row is (key;value)
NB. where each cell is itself a boxed item.
NB. x is key string, y is decoded pjson object matrix
NB. Returns the value (unboxed), or '' if key not found
mcp_getfield =: 4 : 0
  keys =. (< @: , @: >) each 0 {"1 y  NB. extract key column; ravel+rebox each to normalise rank
  idx  =. keys i. < , x                NB. box+ravel x to match; i. returns #keys if not found
  if. idx < # keys do. > 1 { idx { y else. '' end.
)

NB. -----------------------------------------------------------------------
NB. Tool registry - boxed list, each entry is name;description;inputSchema_json
NB. inputSchema is pre-encoded JSON to avoid nested enc_pjson_ complexity

mcp_schema_list_news =: '{"type":"object","properties":{"category":{"type":"string","description":"News category: general, forex, crypto, or merger","default":"general"},"count":{"type":"integer","description":"Number of news items to return","default":10}},"required":[]}'

mcp_schema_get_market_data =: '{"type":"object","properties":{"stock":{"type":"string","description":"Stock ticker symbol, e.g. AAPL"}},"required":["stock"]}'

mcp_schema_get_basic_financials =: '{"type":"object","properties":{"stock":{"type":"string","description":"Stock ticker symbol, e.g. AAPL"},"metric":{"type":"string","description":"Metric group: all, price, valuation, margin, etc.","default":"all"}},"required":["stock"]}'

mcp_schema_get_recommendation_trends =: '{"type":"object","properties":{"stock":{"type":"string","description":"Stock ticker symbol, e.g. AAPL"}},"required":["stock"]}'

MCP_TOOL_REGISTRY =: 0$<''
MCP_TOOL_REGISTRY =: MCP_TOOL_REGISTRY , <('list_news'                 ; 'List latest market news'                          ; mcp_schema_list_news)
MCP_TOOL_REGISTRY =: MCP_TOOL_REGISTRY , <('get_market_data'           ; 'Get market data (quote) for a given stock'        ; mcp_schema_get_market_data)
MCP_TOOL_REGISTRY =: MCP_TOOL_REGISTRY , <('get_basic_financials'      ; 'Get basic financials for a given stock'           ; mcp_schema_get_basic_financials)
MCP_TOOL_REGISTRY =: MCP_TOOL_REGISTRY , <('get_recommendation_trends' ; 'Get recommendation trends for a given stock'      ; mcp_schema_get_recommendation_trends)

NB. -----------------------------------------------------------------------
NB. Encode one tool entry as a JSON object string
NB. y is a boxed triple: <(name;desc;schemastr)
mcp_encode_one_tool =: 3 : 0
  entry =. > y
  NB. J pads boxed strings to equal length - dltb removes trailing spaces
  nm   =. dltb > 0 { entry
  desc =. dltb > 1 { entry
  sch  =.      > 2 { entry
  '{"name":' , (enc_pjson_ nm) , ',"description":' , (enc_pjson_ desc) , ',"inputSchema":' , sch , '}'
)

NB. Returns the full tools JSON array string for tools/list response
mcp_tools_json =: 3 : 0
  entries =. mcp_encode_one_tool each MCP_TOOL_REGISTRY
  '[' , (}. ; (',' , ]) each entries) , ']'
)

NB. -----------------------------------------------------------------------
NB. Wrap a result string in MCP content response JSON
NB. Builds {"content":[{"type":"text","text":"..."}],"isError":false}
mcp_ok_result =: 3 : 0
  textobj =. '{"type":"text","text":' , (enc_pjson_ y) , '}'
  '{"content":[' , textobj , '],"isError":false}'
)

mcp_err_result =: 3 : 0
  textobj =. '{"type":"text","text":' , (enc_pjson_ y) , '}'
  '{"content":[' , textobj , '],"isError":true}'
)

NB. -----------------------------------------------------------------------
NB. Tool dispatcher
NB. x is tool name string, y is decoded pjson arguments object
mcp_calltool =: 4 : 0
  try.
    result =. x mcp_dispatch y
    mcp_ok_result result
  catch.
    mcp_err_result 13!:12''
  end.
)

NB. mcp_dispatch is defined in j-tools/mcp_tool_registry.ijs via agenda (@.).
