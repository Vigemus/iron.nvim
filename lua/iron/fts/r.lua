local r = {}

r.R = {
    command = { "R" },
}

local extend = require("iron.util.tables").extend

local format = function(open, close, cr)
    return function(lines)
        if #lines == 1 then
            return { lines[1] .. cr }
        else
            local new = { open .. lines[1] }
            for line = 2, #lines do
                table.insert(new, lines[line])
            end
            return extend(new, close)
        end
    end
end

r.radian = {
    radian = {
        command = { "radian" },
        format = format("\27[200~", "\27[201~\13", "\13"),
    },
}

return r
