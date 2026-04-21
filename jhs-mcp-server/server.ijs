NB. server.ijs - jmcp MCP server startup
NB. Usage:
NB.   jconsole -js "load '~/jdev/jmcp/jhs-mcp-server/server.ijs'"
NB.
NB. Architecture: a proper JHS application running headless under jconsole.
NB.   - mcp_handler.ijs defines coclass 'mcp' + coinsert 'jhs' with jev_post_raw.
NB.     JHS's getdata detects jev_post_raw_mcp_ (via the locale chain), sets RAW=:1,
NB.     and stores the raw POST body in NV_jhs_.
NB.   - init_jhs_ ends with jfe 1 (15!:16) which blocks under jconsole, so we
NB.     replicate its setup (jhscfg, dobind, sdlisten) and drive the loop ourselves.
NB.   - input_jhs_ has side-effects that prevent it returning headlessly; we call
NB.     getdata'' directly and dispatch to jev_post_raw_mcp_ when RAW=1, URL=mcp.

coclass 'jhs'

NB. -----------------------------------------------------------------------
NB. Path to configuration — the only deployment-specific line
MCP_CONFIG =: '~/jdev/jmcp/j-tools/config.ijs'

NB. -----------------------------------------------------------------------
NB. config_jhs_ is called by jhscfg after configdefault sets defaults.
config_jhs_ =: 3 : 0
  AUTO =: 0
  PORT =: MCP_PORT
)

NB. -----------------------------------------------------------------------
NB. Load JHS core — defines jhscfg, getdata, addOKURL, dobind, etc.
load '~addons/ide/jhs/core.ijs'

NB. -----------------------------------------------------------------------
NB. Load MCP modules — tool verbs, registry, and the mcp locale handler.
NB. mcp_tools.ijs reads MCP_CONFIG_jhs_ which loads tool locales + registry.
NB. mcp_handler.ijs defines coclass 'mcp' with jev_post_raw; getdata detects
NB. jev_post_raw_mcp_ (via locale chain) and sets RAW=:1 on POST /mcp.
load '~/jdev/jmcp/jhs-mcp-server/mcp_tools.ijs'
load '~/jdev/jmcp/jhs-mcp-server/mcp_handler.ijs'

NB. -----------------------------------------------------------------------
NB. Start server and drive the request loop.
NB. Replicates init_jhs_ setup steps, stopping before jfe 1:
NB.   OKURL pre-init — jhscfg sets OKURL=:'' if undefined; addOKURL needs a boxed list
NB.   jhscfg        — runs configdefault (PC_LOG, PC_RECVTIMEOUT, etc.) then config_jhs_
NB.   logappfile    — required by logapp inside getdata; normally set by init_jhs_
NB.   IFJHS_z_      — tells JHS verbs we are running in JHS mode
NB.   LOCALHOST     — set from MCP_LOCALHOST (init_jhs_ hardcodes 127.0.0.1)
NB.   dobind        — creates and binds SKLISTEN on PORT
NB.   sdlisten      — marks socket ready to accept connections
NB.   addOKURL      — exempts /mcp from login redirect (must follow jhscfg)
NB.   getdata       — accepts one connection, parses request, sets RAW/NV/URL
NB.   jev_post_raw_mcp_ — called when RAW=1 and URL=mcp; reads NV_jhs_, sends response

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
