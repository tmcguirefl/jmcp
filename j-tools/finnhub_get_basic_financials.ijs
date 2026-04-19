NB. finnhub_get_basic_financials.ijs - Get basic financials for a stock from Finnhub
NB. Standalone test:
NB.   load '/Users/tomdevel/jdev/jmcp/j-tools/finnhub_get_basic_financials.ijs'
NB.   mcp_get_basic_financials 'AAPL';'all'
NB. Requires FINNHUB_API_KEY to be set in the environment.

coclass 'jhs'

require '~addons/web/gethttp/gethttp.ijs'

NB. -----------------------------------------------------------------------
NB. mcp_get_basic_financials
NB. y is stock;metric (boxed list)
NB.   stock  : symbol string, e.g. 'AAPL'
NB.   metric : metric group string, e.g. 'all', 'price', 'valuation', 'margin'
NB.            (default 'all')
NB. Returns: JSON object string with metric series and annual/quarterly data
mcp_get_basic_financials =: 3 : 0
  'stock metric' =. 2 {. (y , 'UNKNOWN' ; 'all')   NB. defaults
  stock  =. dltb ": > stock
  metric =. dltb ": > metric

  apikey =. dltb 2!:5 'FINNHUB_API_KEY'
  if. 0 = # apikey do.
    'FINNHUB_API_KEY not set' return.
  end.

  url =. 'https://finnhub.io/api/v1/stock/metric?symbol=' , stock , '&metric=' , metric , '&token=' , apikey

  'stdout' gethttp_wgethttp_ url
)
