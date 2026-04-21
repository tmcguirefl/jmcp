NB. mcp_handler.ijs - MCP JSON-RPC handler, registered as a JHS application
NB.
NB. coclass 'mcp' + coinsert 'jhs' makes this a proper JHS page application.
NB. JHS detects jev_post_raw_mcp_ (via the locale chain) and calls it for
NB. every POST /mcp request. NV_jhs_ holds the raw POST body bytes.
NB.
NB. Helpers from the jhs locale (mcp_getfield, mcp_tools_json, htmlresponse,
NB. enc_pjson_, dec_pjson_, gethv, etc.) are referenced with _jhs_ suffix
NB. because this code runs in the mcp locale, not jhs.

coclass 'mcp'
coinsert 'jhs'

NB. -----------------------------------------------------------------------
NB. CRLF for HTTP headers
MCP_CRLF =: (13{a.) , (10{a.)

NB. -----------------------------------------------------------------------
NB. Session store
MCP_SESSIONS  =: 0$<''
MCPSESSIONCTR =: 0

mcp_newsessionid =: 3 : 0
  MCPSESSIONCTR =: >: MCPSESSIONCTR
  'mcp-' , (": MCPSESSIONCTR) , '-' , (": 6!:1'')
)

NB. -----------------------------------------------------------------------
NB. HTTP response senders

NB. x is extra header string ('' for none), y is JSON body string
mcp_send_json =: 4 : 0
  hdrs =. 'HTTP/1.1 200 OK' , MCP_CRLF
  hdrs =. hdrs , 'Content-Type: application/json' , MCP_CRLF
  hdrs =. hdrs , 'Content-Length: ' , (": # y) , MCP_CRLF
  hdrs =. hdrs , 'Cache-Control: no-cache' , MCP_CRLF
  if. 0 < # x do. hdrs =. hdrs , x , MCP_CRLF end.
  hdrs =. hdrs , MCP_CRLF
  htmlresponse_jhs_ hdrs , y
)

mcp_send_202 =: 3 : 0
  r =. 'HTTP/1.1 202 No Content' , MCP_CRLF
  r =. r , 'Content-Length: 0' , MCP_CRLF
  r =. r , MCP_CRLF
  htmlresponse_jhs_ r
)

mcp_send_404 =: 3 : 0
  r =. 'HTTP/1.1 404 Not Found' , MCP_CRLF
  r =. r , 'Content-Length: 0' , MCP_CRLF
  r =. r , MCP_CRLF
  htmlresponse_jhs_ r
)

NB. -----------------------------------------------------------------------
NB. JSON-RPC error builder
NB. y is id;errcode;errmsg
mcp_build_error =: 3 : 0
  'jrpcid errcode errmsg' =. y
  jsoncode =. (": errcode) rplc '_';'-'
  err =. '{"code":' , jsoncode , ',"message":' , (enc_pjson_ errmsg) , '}'
  '{"jsonrpc":"2.0","id":' , (": jrpcid) , ',"error":' , err , '}'
)

mcp_send_error =: 3 : 0
  '' mcp_send_json mcp_build_error y
)

NB. -----------------------------------------------------------------------
NB. Session validation
mcp_validate_session =: 3 : 0
  sid =. gethv_jhs_ 'Mcp-Session-Id:'
  if. (<sid) e. MCP_SESSIONS do. 1
  else.
    mcp_send_404''
    0
  end.
)

NB. -----------------------------------------------------------------------
NB. initialize
mcp_do_initialize =: 3 : 0
  jrpcid =. y
  sid =. mcp_newsessionid''
  MCP_SESSIONS =: MCP_SESSIONS , <sid
  caps   =. '{"tools":{}}'
  sinfo  =. '{"name":"jmcp","version":"0.1.0"}'
  result =. '{"protocolVersion":"2024-11-05","capabilities":' , caps , ',"serverInfo":' , sinfo , '}'
  resp   =. '{"jsonrpc":"2.0","id":' , (": jrpcid) , ',"result":' , result , '}'
  ('Mcp-Session-Id: ' , sid) mcp_send_json resp
)

NB. tools/list
mcp_do_toolslist =: 3 : 0
  jrpcid =. y
  if. -. mcp_validate_session'' do. return. end.
  toolsjson =. mcp_tools_json_jhs_''
  resp =. '{"jsonrpc":"2.0","id":' , (": jrpcid) , ',"result":{"tools":' , toolsjson , '}}'
  '' mcp_send_json resp
)

NB. tools/call
NB. y is jrpcid;reqbody
mcp_do_toolscall =: 3 : 0
  'jrpcid reqbody' =. y
  if. -. mcp_validate_session'' do. return. end.
  params   =. 'params'    mcp_getfield_jhs_ reqbody
  toolname =. 'name'      mcp_getfield_jhs_ params
  toolargs =. 'arguments' mcp_getfield_jhs_ params
  result   =. toolname mcp_calltool_jhs_ toolargs
  resp     =. '{"jsonrpc":"2.0","id":' , (": jrpcid) , ',"result":' , result , '}'
  '' mcp_send_json resp
)

NB. -----------------------------------------------------------------------
NB. Main entry point — JHS calls jev_post_raw_mcp_ for every POST /mcp.
NB. coinsert 'jhs' makes jev_post_raw visible as jev_post_raw_mcp_ via the
NB. locale chain. NV_jhs_ contains the raw POST body.
jev_post_raw =: 3 : 0
  try.
    body   =. dec_pjson_ NV_jhs_
    method =. 'method' mcp_getfield_jhs_ body

    NB. Notifications (no 'id') — acknowledge and stop
    jrpcid =. 'id' mcp_getfield_jhs_ body
    if. jrpcid -: '' do.
      mcp_send_202''
      return.
    end.

    select. method
    case. 'initialize' do.
      mcp_do_initialize jrpcid
    case. 'tools/list' do.
      mcp_do_toolslist jrpcid
    case. 'tools/call' do.
      mcp_do_toolscall (<jrpcid) , <body
    case. do.
      mcp_send_error jrpcid ; _32601 ; 'Method not found: ' , method
    end.

  catch.
    echo 'mcp handler error: ' , 13!:12''
    try. mcp_send_error 0 ; _32700 ; 'Parse error' catch. end.
  end.
)
