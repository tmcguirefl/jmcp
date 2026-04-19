NB. finnhub_get_market_data.ijs - Get quote/market data for a stock from Finnhub
NB. Standalone test:
NB.   load '/Users/tomdevel/jdev/jmcp/j-tools/finnhub_get_market_data.ijs'
NB.   mcp_get_market_data 'AAPL'
NB. Requires FINNHUB_API_KEY to be set in the environment.

coclass 'jhs'

require '~addons/web/gethttp/gethttp.ijs'

NB. -----------------------------------------------------------------------
NB. mcp_get_market_data
NB. y is stock symbol string, e.g. 'AAPL'
NB. Returns: JSON object string with quote fields (c, d, dp, h, l, o, pc, t)
mcp_get_market_data =: 3 : 0
  stock =. dltb ": y

  apikey =. dltb 2!:5 'FINNHUB_API_KEY'
  if. 0 = # apikey do.
    'FINNHUB_API_KEY not set' return.
  end.

  url =. 'https://finnhub.io/api/v1/quote?symbol=' , stock , '&token=' , apikey

  'stdout' gethttp_wgethttp_ url
)
