require "config"
local skynet = require "skynet"
-- local snax = require "snax"

last_hotfix = last_hotfix

local function send_snax(handle, method, ...)
    skynet.send(handle, "snax", 3, method, ...) --send logind system.hotfix
end

local function load_luas(files)
    if #files == 0 then
        return
    end
    print("changed lua files:", #files, "\r\n\t" .. table.concat(files, "\r\n\t"))
    -- cache.clear()
    for handle, _ in pairs(all_snax or {}) do
        send_snax(handle, "hotfix_luas", files)
    end
    -- system.hotfix_luas(files)
end

function load_cfgs(files)
    if #files == 0 then
        return
    end
    print("changed config files:", #files, "\r\n\t" .. table.concat(files, "\r\n\t"))
    for handle, _ in pairs(all_snax or {}) do
        send_snax(handle, "hotfix_cfgs", files)
    end
    hotfix_cfgs(files)
end

local function load_protos(files)
    if #files == 0 then
        return
    end
    print("changed proto files:", #files, "\r\n\t" .. table.concat(files, "\r\n\t"))
    for handle, _ in pairs(all_snax or {}) do
        send_snax(handle, "hotfix_protos", files)
    end
    hotfix_protos(files)
end


function test_hotfix(source, time)
    if not last_hotfix or time > last_hotfix.time then
        return
    end
    if next(last_hotfix.luas) then
        send_snax(source, "hotfix_luas", last_hotfix.luas)
    end
    if next(last_hotfix.cfgs) then
        send_snax(source, "hotfix_cfgs", last_hotfix.cfgs)
    end
end

local function do_hotfix(files)
    local luas = {}
    local cfgs = {}
    local protos = {}
    for path in pairs(files) do
        files_date[path] = files[path]
        local name = get_cfg_name(path)
        if name then
            table.insert(cfgs, name)
        elseif path:sub(-4) == ".lua" then
            table.insert(luas, path)
        elseif path:sub(-6) == ".proto" then
            table.insert(protos, path)
        end

    end
    
    load_luas(luas)
    load_cfgs(cfgs)
    load_protos(protos)

    -- last_hotfix = {
    --     time = Snx.now(),
    --     luas = luas,
    --     cfgs = cfgs,
    --     protos = protos,
    -- }
    return luas, cfgs, protos
end

function auto_hotfix()
    local files = {}
    get_all_files(files)
    for path, date in pairs(files) do
        if files_date[path] == date then
            files[path] = nil
        end
    end
    return do_hotfix(files)
end
