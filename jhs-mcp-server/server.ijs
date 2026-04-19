NB. server.ijs - MCP server entry point
NB. Usage:
NB.   jconsole -js "load '~/jdev/jmcp/jhs-mcp-server/server.ijs'"
NB. Or interactively:
NB.   cd '/Users/tomdevel/jdev/jmcp' then load 'jhs-mcp-server/server.ijs'

NB. 1. Load JHS (also loads pjson addon automatically)
load '~addons/ide/jhs/core.ijs'

coclass 'jhs'

NB. 2. Path to configuration file — only site that needs editing per deployment
MCP_CONFIG =: '~/jdev/jmcp/j-tools/config.ijs'

NB. 3. Define config verb - called by jhscfg AFTER configdefault.
NB.    Reads PORT and AUTO from globals set by config.ijs.
config =: 3 : 0
  AUTO =: 0
  PORT =: MCP_PORT
)

NB. 4. Load MCP modules — mcp_tools.ijs loads config.ijs via MCP_CONFIG
load '~/jdev/jmcp/jhs-mcp-server/mcp_tools.ijs'
load '~/jdev/jmcp/jhs-mcp-server/mcp_handler.ijs'

NB. 4. Allow /mcp URL without login redirect
NB. OKURL is initialized to '' (char) by configdefault inside init.
NB. addOKURL requires a boxed list, so pre-initialize it here first.
OKURL =: 0$<''
addOKURL 'mcp'

NB. 5. Start server: bind socket and run request loop.
NB.    init'' calls jfe 1 which is a no-op in jconsole script mode, so
NB.    we replicate what init does up to the socket bind, then drive the
NB.    request loop ourselves by calling input'' and eval-ing each sentence.
NB.    Control structures require a verb body, so the loop lives in mcp_serve.

mcp_serve =: 3 : 0
  jhscfg''          NB. runs configdefault then our config verb (AUTO=:0, PORT=:65001)
  IFJHS_z_ =: 1
  LOCALHOST =: MCP_LOCALHOST
  SKSERVER_jhs_ =: _1
  r =. dobind''
  if. 0~:r do.
    echo 'bind failed on port ',":PORT
    exit''
  end.
  sdcheck_jsocket_ sdlisten_jsocket_ SKLISTEN,5
  cookie =: 'jcookie=',":6!:0''
  echo 'jmcp MCP server listening on http://',LOCALHOST,':',(":PORT),'/mcp'
  while. 1 do.
    try.
      getdata''    NB. blocks until connection; sets NV_jhs_, URL, METHOD, RAW
      NB. JHS creates a 'mcp' locale with copath=z after getdata.
      NB. jev_post_raw_mcp_ is defined in jhs so use explicit locale suffix.
      if. (1=RAW) *. 'mcp'-:URL do.
        NB. jev_post_raw_mcp_ ends with _ so locale suffix __jhs_ is ill-formed.
        NB. Use ".'' to evaluate the call string in the jhs locale context.
        ".('jev_post_raw_mcp_ ''''')
      end.
    catch.
      NB. socket/connection errors are normal - keep looping
    end.
  end.
)

mcp_serve''
