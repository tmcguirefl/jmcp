NB. finnhub.ijs - All Finnhub API tools in a single isolated locale
NB.
NB. Locale 'finnhub' keeps APIKEY and gethttp state out of the jhs locale.
NB. All four verbs are loaded together; initialization (require, APIKEY) runs once.
NB.
NB. Standalone test (from repo root):
NB.   jconsole
NB.   load 'j-tools/finnhub.ijs'
NB.   list_news_finnhub_ 'general' ; 5
NB.   get_market_data_finnhub_ 'AAPL'
NB.   get_basic_financials_finnhub_ 'AAPL' ; 'all'
NB.   get_recommendation_trends_finnhub_ 'AAPL'

coclass 'finnhub'

require '~addons/web/gethttp/gethttp.ijs'

NB. Read API key once at load time
APIKEY =: dltb 2!:5 'FINNHUB_API_KEY'

NB. -----------------------------------------------------------------------
NB. fetch - GET a URL, return response body as string
fetch =: 3 : 0
  if. 0 = # APIKEY do. 'FINNHUB_API_KEY not set' return. end.
  'stdout' gethttp_wgethttp_ y
)

NB. -----------------------------------------------------------------------
NB. list_news
NB. y is category;count  (e.g. 'general';10)
list_news =: 3 : 0
  'category count' =. 2 {. (y , 'general' ; 10)
  category =. dltb ": > category
  count    =. > count
  fetch 'https://finnhub.io/api/v1/news?category=' , category , '&token=' , APIKEY
)

NB. -----------------------------------------------------------------------
NB. get_market_data
NB. y is stock symbol string  (e.g. 'AAPL')
get_market_data =: 3 : 0
  fetch 'https://finnhub.io/api/v1/quote?symbol=' , (dltb ": y) , '&token=' , APIKEY
)

NB. -----------------------------------------------------------------------
NB. get_basic_financials
NB. y is stock;metric  (e.g. 'AAPL';'all')
get_basic_financials =: 3 : 0
  'stock metric' =. 2 {. (y , 'UNKNOWN' ; 'all')
  stock  =. dltb ": > stock
  metric =. dltb ": > metric
  fetch 'https://finnhub.io/api/v1/stock/metric?symbol=' , stock , '&metric=' , metric , '&token=' , APIKEY
)

NB. -----------------------------------------------------------------------
NB. get_recommendation_trends
NB. y is stock symbol string  (e.g. 'AAPL')
get_recommendation_trends =: 3 : 0
  fetch 'https://finnhub.io/api/v1/stock/recommendation?symbol=' , (dltb ": y) , '&token=' , APIKEY
)
