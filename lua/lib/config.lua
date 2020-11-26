local sharetable = require "skynet.sharetable"
local protobuf = require "protobuf"
local parser = require "parser"
local misc = require "misc"

loaded_cfg = loaded_cfg or {}

function Getcfg(name)
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
    sharetable.update(list)
    for _, name in pairs(list) do
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




