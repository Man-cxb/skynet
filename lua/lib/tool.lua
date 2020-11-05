D = print

function V2S(val, max_dep, cur_dep, sp)
    max_dep = max_dep or 20
    cur_dep = cur_dep or 1
    if cur_dep > max_dep then
        return "..."
    end
    local t = type(val)
    if t == "string" then
        return string.format("%q", val)
    end
    if t ~= "table" then
        return tostring(val)
    end
    local keys = {}
    for k in pairs(val) do
        table.insert(keys, k)
    end
    if #keys == 0 then
        return "{}"
    end
    pcall(table.sort, keys)
    sp = sp or ""
    local nsp = sp .. " "
    local s = "{"
    for _, k in ipairs(keys) do
        s = s .. string.format("\n%s%s = %s,", nsp, k, V2S(val[k], max_dep, cur_dep + 1, nsp))
    end
    return s .. "\n" .. sp .. "}"
end