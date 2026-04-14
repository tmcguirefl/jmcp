NB. server.ijs - MCP server entry point
NB. Usage:
NB.   jconsole -js "load '/Users/tomdevel/jdev/jmcp/jhs-mcp-server/server.ijs'"
NB. Or interactively:
NB.   cd '/Users/tomdevel/jdev/jmcp' then load 'jhs-mcp-server/server.ijs'

NB. 1. Load JHS (also loads pjson addon automatically)
load '~addons/ide/jhs/core.ijs'

coclass 'jhs'

NB. 2. Define config verb - called by jhscfg inside init AFTER configdefault
NB.    This is the correct way to override AUTO without it being overwritten
config =: 3 : 0
  AUTO =: 0       NB. suppress automatic browser launch
  PORT =: 65001   NB. listen port
)

NB. 3. Load MCP modules
NB.    mcp_tools.ijs first - defines mcp_getfield used by mcp_handler.ijs
load '/Users/tomdevel/jdev/jmcp/jhs-mcp-server/mcp_tools.ijs'
load '/Users/tomdevel/jdev/jmcp/jhs-mcp-server/mcp_handler.ijs'

NB. 4. Allow /mcp URL without login redirect
NB. OKURL is initialized to '' (char) by configdefault inside init.
NB. addOKURL requires a boxed list, so pre-initialize it here first.
OKURL =: 0$<''
addOKURL 'mcp'

NB. 5. Start JHS - binds socket, calls config via jhscfg, enters jfe event loop
NB.    This call blocks - the server runs until Ctrl+C
init ''
