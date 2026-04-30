NB. config_jhs_mcp.ijs - single entry point for the jmcp MCP server
NB. Usage:
NB.   jconsole -js "load '~/jdev/jmcp/jhs-mcp-server/config_jhs_mcp.ijs'" > /tmp/jmcp_server.log 2>&1 &

coclass 'jhs'

NB. -----------------------------------------------------------------------
NB. Server settings — MCP_PORT/MCP_LOCALHOST read by config and mcp_serve
MCP_PORT      =: 65001
MCP_LOCALHOST =: '0.0.0.0'

NB. -----------------------------------------------------------------------
NB. config verb - called by jhscfg after configdefault sets defaults.
NB. Do NOT pre-assign PORT here; jhscfg only calls configdefault (which sets
NB. PASS, USER, AUTO, etc.) when PORT is undefined, so we must let jhscfg do
NB. that first, then override PORT and AUTO in our config verb.
config =: 3 : 0
  AUTO =: 0
  PORT =: MCP_PORT
)

NB. -----------------------------------------------------------------------
NB. Load JHS core — defines jhscfg, getdata, addOKURL, dobind, etc.
load '~addons/ide/jhs/core.ijs'

NB. -----------------------------------------------------------------------
NB. MCP_CONFIG points to tool/schema definitions; must be set before mcp_tools.ijs
MCP_CONFIG =: '~/jdev/jmcp/j-tools/config.ijs'

NB. Load MCP modules
load '~/jdev/jmcp/jhs-mcp-server/mcp_tools.ijs'
load '~/jdev/jmcp/jhs-mcp-server/mcp_handler.ijs'

NB. -----------------------------------------------------------------------
NB. Start server and drive the request loop.
NB. We replicate init_jhs_ setup without calling jfe 1, which blocks jconsole.
mcp_serve =: 3 : 0
  OKURL =: 0$<''
  jhscfg''
  logappfile =: <jpath '~user/jmcp.log'
  IFJHS_z_ =: 1
  LOCALHOST =: MCP_LOCALHOST
  cookie =: 'jcookie=' , ": 6!:0''
  SKSERVER_jhs_ =: _1
  r =. dobind''
  if. 0 ~: r do.
    echo 'bind failed on port ' , ": PORT
    exit''
  end.
  sdcheck_jsocket_ sdlisten_jsocket_ SKLISTEN , 5
  addOKURL 'mcp'
  echo 'jmcp listening on http://' , LOCALHOST , ':' , (": PORT) , '/mcp'
  while. 1 do.
    try.
      getdata''
      if. (1=RAW) *. 'mcp' -: URL do.
        jev_post_raw_mcp_ ''
      end.
    catch.
      NB. socket/connection errors are normal - keep looping
    end.
  end.
)

mcp_serve''
