local functional = {}

functional.keys = function(tbl)
    local new = {}
    for k, _ in pairs(tbl) do
        table.insert(new, k)
    end
    return new
end

functional.values = function(tbl)
    local new = {}
    for _, v in pairs(tbl) do
        table.insert(new, v)
    end
    return new
end

return functional
