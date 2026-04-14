NB. mcp_handler.ijs - MCP JSON-RPC handler for JHS
NB. Defines jev_post_raw_mcp_ which JHS calls for every POST to /mcp
NB. Loaded by server.ijs after mcp_tools.ijs
NB.
NB. LOCALE NOTE: JHS creates a 'mcp' locale when processing POST /mcp.
NB. jev_post_raw_mcp_ ends up running in that locale (copath: z only).
NB. All references to jhs-locale globals and helpers must use _jhs_ suffix.

coclass 'jhs'

NB. -----------------------------------------------------------------------
NB. CRLF for HTTP headers (CR=13, LF=10)
MCP_CRLF =: (13{a.) , (10{a.)

NB. -----------------------------------------------------------------------
NB. Session store - boxed vector of active session ID strings
MCP_SESSIONS   =: 0$<''
MCPSESSIONCTR  =: 0

NB. Generate a unique session ID using monotonic counter + elapsed time
mcp_newsessionid =: 3 : 0
  MCPSESSIONCTR_jhs_ =: >: MCPSESSIONCTR_jhs_
  'mcp-' , (": MCPSESSIONCTR_jhs_) , '-' , (": 6!:1'')
)

NB. -----------------------------------------------------------------------
NB. HTTP response senders - all call htmlresponse which sends and closes socket

NB. x is extra header string ('' or 'Header: value'), y is JSON body string
mcp_send_json =: 4 : 0
  hdrs =. 'HTTP/1.1 200 OK' , MCP_CRLF_jhs_
  hdrs =. hdrs , 'Content-Type: application/json' , MCP_CRLF_jhs_
  hdrs =. hdrs , 'Content-Length: ' , (": # y) , MCP_CRLF_jhs_
  hdrs =. hdrs , 'Cache-Control: no-cache' , MCP_CRLF_jhs_
  if. 0 < # x do. hdrs =. hdrs , x , MCP_CRLF_jhs_ end.
  hdrs =. hdrs , MCP_CRLF_jhs_
  htmlresponse_jhs_ hdrs , y
)

NB. 202 No Content - for notifications (no response body needed)
mcp_send_202 =: 3 : 0
  r =. 'HTTP/1.1 202 No Content' , MCP_CRLF_jhs_
  r =. r , 'Content-Length: 0' , MCP_CRLF_jhs_
  r =. r , MCP_CRLF_jhs_
  htmlresponse_jhs_ r
)

NB. 404 Not Found - for unknown/expired session
mcp_send_404 =: 3 : 0
  r =. 'HTTP/1.1 404 Not Found' , MCP_CRLF_jhs_
  r =. r , 'Content-Length: 0' , MCP_CRLF_jhs_
  r =. r , MCP_CRLF_jhs_
  htmlresponse_jhs_ r
)

NB. -----------------------------------------------------------------------
NB. Build a JSON-RPC error response string
NB. y is id;errcode;errmsg
mcp_build_error =: 3 : 0
  'jrpcid errcode errmsg' =. y
  NB. J uses _ for negatives (e.g. _32601) but JSON requires - (e.g. -32601)
  jsoncode =. (": errcode) rplc '_';'-'
  err =. '{"code":' , jsoncode , ',"message":' , (enc_pjson_ errmsg) , '}'
  '{"jsonrpc":"2.0","id":' , (": jrpcid) , ',"error":' , err , '}'
)

NB. Send a JSON-RPC error response
mcp_send_error =: 3 : 0
  '' mcp_send_json_jhs_ mcp_build_error_jhs_ y
)

NB. -----------------------------------------------------------------------
NB. Session validation
NB. Returns 1 if session is valid; sends 404 and returns 0 if not
mcp_validate_session =: 3 : 0
  sid =. gethv_jhs_ 'Mcp-Session-Id:'
  if. (<sid) e. MCP_SESSIONS_jhs_ do. 1
  else.
    mcp_send_404_jhs_''
    0
  end.
)

NB. -----------------------------------------------------------------------
NB. initialize handler
NB. y is jrpcid (the id value from the request, already a J noun)
mcp_do_initialize =: 3 : 0
  jrpcid =. y
  NB. Generate and register session ID
  sid =. mcp_newsessionid_jhs_''
  MCP_SESSIONS_jhs_ =: MCP_SESSIONS_jhs_ , <sid
  NB. Build response JSON inline as strings (avoids nested enc_pjson_ complexity)
  caps   =. '{"tools":{}}'
  sinfo  =. '{"name":"jmcp","version":"0.1.0"}'
  result =. '{"protocolVersion":"2024-11-05","capabilities":' , caps , ',"serverInfo":' , sinfo , '}'
  resp   =. '{"jsonrpc":"2.0","id":' , (": jrpcid) , ',"result":' , result , '}'
  NB. Send with Mcp-Session-Id header
  ('Mcp-Session-Id: ' , sid) mcp_send_json_jhs_ resp
)

NB. tools/list handler
mcp_do_toolslist =: 3 : 0
  jrpcid =. y
  if. -. mcp_validate_session_jhs_'' do. return. end.
  toolsjson =. mcp_tools_json_jhs_''
  resp =. '{"jsonrpc":"2.0","id":' , (": jrpcid) , ',"result":{"tools":' , toolsjson , '}}'
  '' mcp_send_json_jhs_ resp
)

NB. tools/call handler
NB. y is jrpcid;reqbody  where reqbody is the decoded pjson request object
mcp_do_toolscall =: 3 : 0
  'jrpcid reqbody' =. y
  if. -. mcp_validate_session_jhs_'' do. return. end.
  params   =. 'params'    mcp_getfield_jhs_ reqbody
  toolname =. 'name'      mcp_getfield_jhs_ params
  toolargs =. 'arguments' mcp_getfield_jhs_ params
  result   =. toolname mcp_calltool_jhs_ toolargs
  resp     =. '{"jsonrpc":"2.0","id":' , (": jrpcid) , ',"result":' , result , '}'
  '' mcp_send_json_jhs_ resp
)

NB. -----------------------------------------------------------------------
NB. Main MCP entry point - called by JHS for every POST to /mcp
NB. JHS creates a 'mcp' locale (copath: z only) so all helpers need _jhs_ suffix.
jev_post_raw_mcp_ =: 3 : 0
  try.
    body   =. dec_pjson_ NV_jhs_
    method =. 'method' mcp_getfield_jhs_ body

    NB. Notifications have no 'id' field - return 202 and stop
    jrpcid =. 'id' mcp_getfield_jhs_ body
    if. jrpcid -: '' do.
      mcp_send_202_jhs_''
      return.
    end.

    NB. Dispatch on method
    select. method
    case. 'initialize' do.
      mcp_do_initialize_jhs_ jrpcid
    case. 'tools/list' do.
      mcp_do_toolslist_jhs_ jrpcid
    case. 'tools/call' do.
      mcp_do_toolscall_jhs_ (<jrpcid) , <body
    case. do.
      mcp_send_error_jhs_ jrpcid ; _32601 ; 'Method not found: ' , method
    end.

  catch.
    NB. Parse/dispatch error - log it, send error only if socket still open
    echo 'jev_post_raw_mcp_ error: ', 13!:12''
    if. SKSERVER_jhs_ ~: _1 do.
      mcp_send_error_jhs_ 0 ; _32700 ; 'Parse error'
    end.
  end.
)
