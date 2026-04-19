NB. add.ijs - Add two numbers
NB. Standalone test: load 'j-tools/add.ijs'  then  mcp_add 3;5  gives  8

coclass 'jhs'

NB. y is a;b (boxed list of two numbers)
NB. @: is infinite-rank atop: apply > to y at all ranks, then +/
mcp_add =: +/ @: >
