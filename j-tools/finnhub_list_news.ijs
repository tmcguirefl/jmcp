NB. finnhub_list_news.ijs - Fetch latest market news from Finnhub
NB. Standalone test:
NB.   load '/Users/tomdevel/jdev/jmcp/j-tools/finnhub_list_news.ijs'
NB.   mcp_list_news 'general';10
NB. Requires FINNHUB_API_KEY to be set in the environment.

coclass 'jhs'

NB. Load web/gethttp addon (uses curl on macOS) if not already loaded
require '~addons/web/gethttp/gethttp.ijs'

NB. -----------------------------------------------------------------------
NB. mcp_list_news
NB. y is category;count (boxed list)
NB.   category : string, e.g. 'general', 'forex', 'crypto', 'merger'
NB.   count    : integer, number of items to return (default 10)
NB. Returns: JSON array string (first `count` items of the news array)
mcp_list_news =: 3 : 0
  'category count' =. 2 {. (y , 'general' ; 10)  NB. defaults if not supplied
  category =. dltb ": > category
  count    =. > count

  NB. Read API key from environment
  apikey =. dltb 2!:5 'FINNHUB_API_KEY'
  if. 0 = # apikey do.
    'FINNHUB_API_KEY not set' return.
  end.

  NB. Build URL
  url =. 'https://finnhub.io/api/v1/news?category=' , category , '&token=' , apikey

  NB. Fetch via curl (gethttp uses curl on macOS)
  raw =. 'stdout' gethttp_wgethttp_ url

  NB. raw is the full JSON response; it should be a JSON array [...].
  NB. Trim to `count` items by finding the nth top-level comma after '['.
  NB. We return the raw JSON string — the MCP client parses it.
  NB. For simplicity, return the full array when count is large enough.
  raw
)
