local misc = require "misc"

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

function Tbtostr(val, cache)
    cache = cache or {}
    local t = type(val)
    if t == "string" then
        return string.format("%q", val)
    end
    if t ~= "table" then
        return tostring(val)
    end
    if cache[val] then
        return val
    end
    cache[val] = true
    local keys = {}
    for k in pairs(val) do
        table.insert(keys, k)
    end
    if #keys == 0 then
        return "{}"
    end
    pcall(table.sort, keys)
    local len = #keys
    local s = "{"
	for i, k in ipairs(keys) do
		if type(k) == "string" then
			s = s .. string.format("%s = %s", k, Tbtostr(val[k], cache))
		else
			s = s .. string.format("%s",  Tbtostr(val[k], cache))
        end
        if i ~= len then
            s = s .. ", "
        end
    end
    return s ..  "}"
end

function list_files(dir)
    local base
    if not dir or dir == "" then
        dir = "./"
        base = ""
    elseif dir:sub(-1) == "/" then
        base = dir
    else
        base = dir .. "/"
    end
    local map = misc.list_dir(dir)
    if not map then
        return nil
    end
    local list = {}
    for name, typ in pairs(map) do
        local fullname = base .. name
        local info = misc.stat_file(fullname) or {}
        info.name = name
        info.fullname = fullname
        info.type = typ
        table.insert(list, info)
    end
    return list
end