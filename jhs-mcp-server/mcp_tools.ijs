NB. mcp_tools.ijs - Tool registry and dispatcher
NB. Defines: mcp_getfield, MCP_TOOL_REGISTRY, mcp_tools_json, mcp_dispatch
NB. mcp_ok_result, mcp_err_result
NB. Loaded by server.ijs before mcp_handler.ijs

coclass 'jhs'

NB. Load tool implementations
load '/Users/tomdevel/jdev/jmcp/j-tools/add.ijs'
load '/Users/tomdevel/jdev/jmcp/j-tools/multiply.ijs'

NB. -----------------------------------------------------------------------
NB. mcp_getfield - look up a key in a pjson-decoded object
NB. pjson dec_object returns a boxed 2-col matrix; each row is (key;value)
NB. where each cell is itself a boxed item.
NB. x is key string, y is decoded pjson object matrix
NB. Returns the value (unboxed), or '' if key not found
mcp_getfield =: 4 : 0
  i =. 0
  while. i < # y do.
    row =. i { y
    k =. > 0 { row
    if. k -: x do. return. > 1 { row end.
    i =. >: i
  end.
  ''
)

NB. -----------------------------------------------------------------------
NB. Tool registry - boxed list, each entry is name;description;inputSchema_json
NB. inputSchema is pre-encoded JSON to avoid nested enc_pjson_ complexity

mcp_schema_add =: '{"type":"object","properties":{"a":{"type":"number","description":"First number"},"b":{"type":"number","description":"Second number"}},"required":["a","b"]}'

mcp_schema_multiply =: '{"type":"object","properties":{"a":{"type":"number","description":"First number"},"b":{"type":"number","description":"Second number"}},"required":["a","b"]}'

MCP_TOOL_REGISTRY =: 0$<''
MCP_TOOL_REGISTRY =: MCP_TOOL_REGISTRY , <('add' ; 'Add two numbers a and b' ; mcp_schema_add)
MCP_TOOL_REGISTRY =: MCP_TOOL_REGISTRY , <('multiply' ; 'Multiply two numbers a and b' ; mcp_schema_multiply)

NB. -----------------------------------------------------------------------
NB. Encode one tool entry as a JSON object string
NB. y is a boxed triple: <(name;desc;schemastr)
mcp_encode_one_tool =: 3 : 0
  entry =. > y
  nm   =. > 0 { entry
  desc =. > 1 { entry
  sch  =. > 2 { entry
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

NB. x is tool name, y is decoded arguments object
NB. Returns result as string (using ": to format numbers)
mcp_dispatch =: 4 : 0
  a =. 'a' mcp_getfield y
  b =. 'b' mcp_getfield y
  select. x
  case. 'add'      do. ": mcp_add a ; b
  case. 'multiply' do. ": mcp_multiply a ; b
  case. do. 'unknown tool: ' , x assert 0
  end.
)
