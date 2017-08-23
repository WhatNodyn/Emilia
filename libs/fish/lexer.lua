local l = require("lpeg"):locale()

-- Sep are sets of generic separator characters
local sep = {}
sep.command = l.S("\n\r;")
sep.token = l.space - l.S("\n\r")

-- Reserved characters are those with special meaning
local reserved = l.space + l.S("(){}'$%|&;\\\"")

-- Number are... well actually, digits in one case but numbers in all others
local number = {}
number.hexadecimal = l.R("09") + l.R("AF") + l.R("af")
number.unsigned = (l.R("09") ^ 1) / tonumber
number.signed = ((l.P("-") ^ -1) * (l.R("09") ^ 1)) / tonumber

-- Constr are constructed separators, as they may be used in shellcode
local constr = {}
constr.pipe = (l.space ^ 0) * l.C("|") * (l.space ^ 0)
constr.ampersand = (l.space ^ 0) * l.C("&") * (l.space ^ 0)
constr.semicolon = (sep.token ^ 0) * l.Cc(";") * sep.command * ((l.space + ";") ^ 0)
constr.command = (constr.ampersand + constr.semicolon) ^ -1
constr.token = sep.token ^ 0

-- Escape functions
local function code(char, n)
    return char * number.hexadecimal * number.hexadecimal ^ (1 - n)
end

local function unescape(code)
    local known = {a="\a", b="\b", e="\027", f="\f", n="\n", r="\r", t="\t", v="\v"}
    if #code == 1 and (known[code] or reserved:match(code)) then
        return known[code] or code
    elseif #code == 1 then
        return "\\" .. code
    end

    code = tonumber(code:sub(2), 16)
    local result = ""
    while code > 255 do
        result = string.char(bit.band(code, 255)) .. result
        code = bit.rshift(code, 8)
    end
    return string.char(code) .. result
end

-- Expr are subtoken parsing elements
local expr = {}
expr.normal = l.C((l.P(1) - reserved) ^ 1)
expr.escape = l.P("\\") * l.C(code("x", 2) + code("u", 4) + code("U", 8) + (l.P(1) - "xuU")) / unescape
expr.range = l.Ct(number.signed * constr.token * ".." * constr.token * number.signed)
expr.identifier = (l.R("az") + l.R("AZ") + l.R("09") + "_") ^ 1
expr.index = l.Cg(l.Ct((constr.token * (expr.range + number.signed + l.C(expr.identifier))) ^ 0) * constr.token, "index")
expr.variable = l.P({l.Ct(l.P("$") * l.Cg(expr.identifier + l.V(1), "variable") * ("[" * expr.index * "]") ^ -1)})
expr.quotes = l.P('"') * (expr.escape + expr.variable + l.C((l.P(1) - l.S('"\\$')) ^ 1)) ^ 0 * l.P('"')
expr.squotes = l.P("'") * (expr.escape + l.C((l.P(1) - l.S("'\\")) ^ 1)) ^ 0 * l.P("'")
expr.fquotes = l.P('"') * (expr.escape + l.C((l.P(1) - l.S('"\\')) ^ 1)) ^ 0 * l.P('"')
expr.farray = l.P({l.P("{") * (expr.escape + expr.fquotes + expr.squotes + l.V(1) + l.C((l.P(1) - l.S("\\{},")) ^ 1)) ^ 0 * l.P("}")})
expr.name = l.Cg(constr.token * l.Ct((expr.escape + expr.squotes + expr.fquotes + expr.farray + expr.normal) ^ 1), 0)
expr.substitution = l.P("(") * (l.Ct(l.Cg(l.V("script"), "script") + l.P(''))) * l.P(")")
expr.special = expr.escape + expr.variable + l.V("array") + expr.substitution + expr.quotes + expr.squotes

-- Script contains the real elements
local script = lpeg.P {
    l.V("script") * -1;

    arrayElement = l.Ct((expr.special + l.C(((l.P(1) - l.S(";|&{}(),'$\\\"")) + (lpeg.B(",") * ",")) ^ 1)) ^ 1),
    array = l.P("{") * l.Ct(l.V("arrayElement") * ((l.P(",") * l.V("arrayElement")) ^ 0) + l.C("")) * l.P("}"),

    token = l.Ct((expr.special + expr.normal) ^ 1),
    command = l.Ct(expr.name * (constr.token * l.V("token")) ^ 0) * (constr.pipe * l.V("command")) ^ -1 * (sep.token ^ 0),
    script = l.Ct((constr.semicolon ^ -1) / 0 * l.V("command") * (constr.command * l.V("command")) ^ 0 * constr.command)
}

return script
