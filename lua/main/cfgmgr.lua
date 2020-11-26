local sharetable = require "skynet.sharetable"
local CFG_DIR = "cfg/"
local SYS_DIR = "system/"
local CFG_EXT = ".config"

cfg_sim_def = cfg_sim_def or {}
cfg_sim_map = cfg_sim_map or {}

local CFG_CONVERT = {}

function get_cfg_name(path)
    if path:sub(1, #CFG_DIR) == CFG_DIR and path:sub(-#CFG_EXT) == CFG_EXT then
        return path:sub(#CFG_DIR + 1, -#CFG_EXT - 1):gsub("/", ".")
    elseif path:sub(1, #SYS_DIR) == SYS_DIR and path:sub(-#CFG_EXT) == CFG_EXT then
        return path:sub(1, -#CFG_EXT - 1):gsub("/", ".")
    end
end

function read_config_path(path)
    local name = get_cfg_name(path)
    if not name then
        return false
    end
    local file = io.open(path)
    local text = file:read("*a")
    file:close()
    local env = setmetatable({}, {__index = _ENV})
    local func = assert(load(text, "@" .. name, "bt", env))
    local ret = func()
    setmetatable(env, nil)
    local cfg = ret and ret or env
    local conv = CFG_CONVERT[name]
    if conv then
        cfg = conv(cfg)
    end
    sharetable.loadtable(name, cfg)
    return true, name
end

function CFG_CONVERT:attr_id()
    local tbl = {}
    for k, v in pairs(self) do
        tbl[v.macro] = v
        tbl[k] = v
    end
    return tbl
end

CFG_CONVERT["system.service"] = function(self)
    local tbl = {}
    for k, v in pairs(self) do
        local t = tbl[v.harbor_id]
        if not t then
            t = {}
            tbl[v.harbor_id] = t
        end
        t[k] = v
    end

    local ret = {}
    for id, list  in pairs(tbl) do
        local keys = {}
        for k, v in pairs(list) do
            table.insert(keys, k)
        end
        table.sort(keys)
        local ret1 = {}
        for _, key in pairs(keys) do
            table.insert(ret1, list[key])
        end
        ret[id] = ret1
    end
    return ret
end