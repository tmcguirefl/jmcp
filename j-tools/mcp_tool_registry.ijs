NB. mcp_tool_registry.ijs - Agenda-based tool dispatcher
NB. Loaded by mcp_tools.ijs after finnhub.ijs is loaded.
NB. Defines: MCP_DISPATCH_NAMES, MCP_DISPATCH_GERUNDS, mcp_dispatch
NB.
NB. Dispatch works via J's agenda (@.):
NB.   x mcp_dispatch y  =>  mcp_tool_selector returns integer index
NB.                          agenda selects the corresponding gerund
NB.                          selected verb is called with original x and y
NB.
NB. MCP_DISPATCH_NAMES has N entries; i. returns N on a miss.
NB. MCP_DISPATCH_GERUNDS has N+1 entries; index N routes to mcp_run_unknown_tool.
NB. Adding a new tool: append its name to MCP_DISPATCH_NAMES and its
NB. adapter verb (before mcp_run_unknown_tool) to MCP_DISPATCH_GERUNDS.

coclass 'jhs'

NB. -----------------------------------------------------------------------
NB. Adapter verbs - dyadic: x=tool name, y=decoded pjson args object
NB. Agenda always calls the selected verb dyadically, so all must be 4:0.
NB. x is ignored except in mcp_run_unknown_tool where it names the bad tool.

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

NB. Fallback for unregistered tools - x carries the tool name for the error message
mcp_run_unknown_tool =: 4 : 0
  'unknown tool: ' , x assert 0
)

NB. -----------------------------------------------------------------------
NB. Dispatch table - names list and gerund list must stay in the same order.

MCP_DISPATCH_NAMES =: 'list_news' ; 'get_market_data' ; 'get_basic_financials' ; 'get_recommendation_trends'

MCP_DISPATCH_GERUNDS =: mcp_run_list_news`mcp_run_get_market_data`mcp_run_get_basic_financials`mcp_run_get_recommendation_trends`mcp_run_unknown_tool

NB. -----------------------------------------------------------------------
NB. Selector verb - x is tool name, y is args object (ignored here).
NB. Returns index into MCP_DISPATCH_GERUNDS.
NB. i. on a 4-element list returns 4 on a miss, routing to mcp_run_unknown_tool.
mcp_tool_selector =: 4 : 0
  MCP_DISPATCH_NAMES_jhs_ i. < , x
)

NB. -----------------------------------------------------------------------
NB. mcp_dispatch - x is tool name string, y is decoded pjson args object
mcp_dispatch =: MCP_DISPATCH_GERUNDS @. mcp_tool_selector
