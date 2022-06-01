local bracketed_paste = require("iron.fts.common").bracketed_paste
local r = {}

r.R = {
    command = { "R" },
}

r.radian = {
    command = { "radian" },
    format = bracketed_paste
}

return r
