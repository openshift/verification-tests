OPT_SYM = '(?: :(\S+))?'
SYM = ':(\S+)'
OPT_QUOTED = '(?: "(.+?)")?'
QUOTED = '"(.+?)"'
HTTP_URL = '(https?:\/\/.+)'
USER = 'the( \\S+)? user'
NUMBER = '([0-9]+|<%=.+?%>)'
WORD = '(\w+|<%=.+?%>)'
OPT_WORD = "(?: #{WORD})?"
NO_SPACE_STR = '([\S]+|<%=.+?%>)'
# use for regular expression
RE='/(.+?)/'
