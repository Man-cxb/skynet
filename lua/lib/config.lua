local sharetable = require "skynet.sharetable"
local protobuf = require "protobuf"
local parser = require "parser"
local misc = require "misc"

files_date = files_date or {} -- 保存文件路径和文件修改时间戳 {{[path] = time}}
loaded_cfg = loaded_cfg or {} -- 配置缓存

local CFG_DIR = "cfg/"
local SYS_DIR = "system/"
local CFG_EXT = ".config"

local CFG_CONVERT = {}

function get_cfg_name(path)
    if path:sub(1, #CFG_DIR) == CFG_DIR and path:sub(-#CFG_EXT) == CFG_EXT then
        return path:sub(#CFG_DIR + 1, -#CFG_EXT - 1):gsub("/", ".")
    elseif path:sub(1, #SYS_DIR) == SYS_DIR and path:sub(-#CFG_EXT) == CFG_EXT then
        return path:sub(1, -#CFG_EXT - 1):gsub("/", ".")
    end
end

local function read_config_path(path)
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

function get_all_files(tb)
    local function get_files_date(files, dir)
        local list = list_files(dir)
        for _, file in ipairs(list) do
            if not file.isdir then
                files[file.fullname] = file.time
            else
                get_files_date(files, file.fullname)
            end
        end
    end

    local dirs = {"cfg/", "system/", "lua/", "proto/"} -- 加载这4个目录下的文件
    for _, dir in pairs(dirs) do
        get_files_date(tb, dir)
    end
end

function init_cfg()
    get_all_files(files_date)
    local cfgs = {}
    for path in pairs(files_date) do
        local ok, name = read_config_path(path)
        if ok then
            table.insert(cfgs, name)
        end
    end
    print("init_cfg:", Tbtostr(cfgs))
end

function GetCfg(name)
    local cfg = loaded_cfg[name]
    if cfg then
        return cfg
    end

    local config = sharetable.query(name)
    if not config then
        return nil
    end
    loaded_cfg[name] = config
    return config
end

-- 热更配置
function hotfix_cfgs(list)
    for _, name in pairs(list) do
        sharetable.update(name)
        if loaded_cfg[name] then
            loaded_cfg[name] = sharetable.query(name)
        end
    end
end

local proto_register_flag
function register_proto()
    proto_register_flag = true
    -- protobuf.clear()
    local path = "./proto"
    local map = misc.list_dir(path)
    for filename in pairs(map or {}) do
       parser.register(filename, path)
    end
end

-- 热更协议
function hotfix_protos(protos)
    if proto_register_flag then
        -- protobuf.clear()
        parser.register(protos, "proto/")
    end
end
