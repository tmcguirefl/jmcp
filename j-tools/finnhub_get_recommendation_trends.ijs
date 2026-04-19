NB. finnhub_get_recommendation_trends.ijs - Get analyst recommendation trends for a stock
NB. Standalone test:
NB.   load '/Users/tomdevel/jdev/jmcp/j-tools/finnhub_get_recommendation_trends.ijs'
NB.   mcp_get_recommendation_trends 'AAPL'
NB. Requires FINNHUB_API_KEY to be set in the environment.

coclass 'jhs'

require '~addons/web/gethttp/gethttp.ijs'

NB. -----------------------------------------------------------------------
NB. mcp_get_recommendation_trends
NB. y is stock symbol string, e.g. 'AAPL'
NB. Returns: JSON array string with buy/hold/sell/strongBuy/strongSell counts by period
mcp_get_recommendation_trends =: 3 : 0
  stock =. dltb ": y

  apikey =. dltb 2!:5 'FINNHUB_API_KEY'
  if. 0 = # apikey do.
    'FINNHUB_API_KEY not set' return.
  end.

  url =. 'https://finnhub.io/api/v1/stock/recommendation?symbol=' , stock , '&token=' , apikey

  'stdout' gethttp_wgethttp_ url
)
