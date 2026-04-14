NB. multiply.ijs - Multiply two numbers
NB. Standalone test: load 'j-tools/multiply.ijs'  then  mcp_multiply 6;7  gives  42

coclass 'jhs'

NB. y is a;b (boxed list of two numbers)
NB. @: is infinite-rank atop: apply > to y at all ranks, then */
mcp_multiply =: */ @: >
