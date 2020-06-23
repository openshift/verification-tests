OPT_SYM = '(?: :(\S+))?'
SYM = ':(\S+)'
OPT_QUOTED = '(?: "([^"\n]+)")?'
QUOTED = '"([^"\n]+)"'
HTTP_URL = '(https?:\/\/.+)'
USER = 'the( \\S+)? user'
NUMBER = '([0-9]+|<%=.+?%>)'
WORD = '(\w+|<%=.+?%>)'
OPT_WORD = "(?: #{WORD})?"
# use for regular expression
RE='/([^/\n]+)/'
