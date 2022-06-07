local bracketed_paste = require("iron.fts.common").bracketed_paste
local r = {}

r.R = {
    command = { "R" },
    format = bracketed_paste
}

r.radian = {
    command = { "radian" },
    format = bracketed_paste
}

return r
