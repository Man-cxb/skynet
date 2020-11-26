require "cfgmgr"

last_hotfix = last_hotfix
files_date = files_date or {} -- 保存文件路径和文件修改时间戳 {{[path] = time}}
loaded_cfg = loaded_cfg or {}

local function send_snx(handle, method, ...)
    -- Snx.rawsend(handle, "system", method, ...)
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

local function load_luas(files)
    if #files == 0 then
        return
    end
    print("changed lua files:", #files, "\r\n\t" .. table.concat(files, "\r\n\t"))
    -- cache.clear()
    -- for handle, _ in pairs(all_snx) do
    --     send_snx(handle, "hotfix_luas", files)
    -- end
    -- system.hotfix_luas(files)
end

function load_cfgs(files)
    if #files == 0 then
        return
    end
    print("changed config files:", #files, "\r\n\t" .. table.concat(files, "\r\n\t"))
    -- local cfg_def = read_cfgs(files)
    -- for handle, _ in pairs(all_snx) do
    --     send_snx(handle, "hotfix_cfgs", cfg_def)
    -- end
    -- system.hotfix_cfgs(cfg_def)
end

local function load_protos(files)
    if #files == 0 then
        return
    end
    print("changed proto files:", #files, "\r\n\t" .. table.concat(files, "\r\n\t"))
    -- for handle, _ in pairs(all_snx) do
    --     send_snx(handle, "hotfix_protos", files)
    -- end
    -- system.hotfix_protos(files)
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

function test_hotfix(source, time)
    if not last_hotfix or time > last_hotfix.time then
        return
    end
    if next(last_hotfix.luas) then
        send_snx(source, "hotfix_luas", last_hotfix.luas)
    end
    if next(last_hotfix.cfgs) then
        send_snx(source, "hotfix_cfgs", last_hotfix.cfgs)
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
