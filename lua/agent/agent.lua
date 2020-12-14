local skynet = require "skynet"
local snax = require "snax"
local datacenter = require "skynet.datacenter"

cjson = require "cjson"
local err_cfg = {}

g_player_id = g_player_id
g_agent_ip = g_agent_ip
g_agent_fd = g_agent_fd
g_gate_handle = g_gate_handle
g_player = g_player

function init(player_id, gate_handle, agent_fd)
	D("agent start")
    require "include"
    g_player_id = player_id
    g_gate_handle = gate_handle
    g_agent_fd = agent_fd
end

function exit(...)

end

local sevobj = {}
function get_server_obj(name)
	if sevobj[name] then
		return sevobj[name]
	end
	local key = name .. "_handle"
	local handle = datacenter.get(key)
	assert(handle, "get_server_obj error, key " .. key)
	local obj = snax.bind(handle, name)
	sevobj[name] = obj
	return obj
end

local not_show_proto = {
	["cs_ping"] = true,
	["sc_ping"] = true,
}
local function show_proto(title, name, proto)
	if not_show_proto[name] then
        return
	end
	-- local Debug = GetCfg("system.debug")
    -- local DbgMod = Debug.DbgMod
    -- local open = DbgMod.proto
    -- if open == nil then
    --     open = DbgMod.all
    -- end
    -- if not open then
    --     return
	-- end
	skynet.error(title .. ":", name, Tbtostr(proto))
end

local proto_cb = {}
function register_proto_cb(modue_name, tbl)
    if tbl and type(tbl) == "table" then
        proto_cb[modue_name] = tbl
        return tbl
    end

    local old = proto_cb[modue_name]
    if not old then
        old = {}
        proto_cb[modue_name] = old
    end
    return old
end

function dispatch_proto(proto, name)
    local modue_name = name:sub(4, 2+(name:sub(4):find("_") or #name - 2))
    local handle = skynet.localname("." .. modue_name)
    if not handle then
        accept.send_err(name, 0, "未找到对应模块" .. modue_name, proto.session)
        return
    end
    if not g_player_id then
         accept.send_err(name, 0, "玩家未登录", proto.session)
         return
	end
    -- Snx.post(handle, "player_msg", g_player_id, name, proto)
end

local function get_proto_func(proto_name)
    local last = proto_name:sub(4):find("_")
    if last then
        last = last + 2
    else
        last = #proto_name
    end

    local module_name = proto_name:sub(4, last)
    local tbl = proto_cb[module_name]
    if tbl then
        return tbl[proto_name] or tbl.default, module_name
    end
    return dispatch_proto
end

function accept.dispatch_proto(proto_name, body)
    show_proto("rec", proto_name, body)

	local func = get_proto_func(proto_name)
	if not func then
        D("找不到协议对应的处理方法")
        return
	end

	local ok, ret, code, msg = xpcall(func, debug.traceback, proto_name, body)
    if not ok then
		D("error_handle", debug.traceback(ret, 2))
        send_err(proto_name, "COM_SYS_FAIL", "协议处理失败: " .. body, proto_name.session)
        return
    end
	-- local agentmgr = snax.bind(".agentmgr", "agentmgr")
	-- local ok = agentmgr.post.test_from_agent("dsss")
	-- D("--dd-->",ok)
	-- D("--dd-->",V2S(agentmgr))

    if ret == false then
        send_err(proto_name, code, msg, proto_name.session)
        return
    elseif ret == true then
        send_err(proto_name, "SUCCESS", nil, proto_name.session)
	end
end

function accept.reconnect(fd, gate_handle, ip)
    g_agent_ip = ip
    g_agent_fd = fd
    g_gate_handle = gate_handle
end

function send_client_proto(name, body)
    show_proto("send", name, body)
	skynet.send(g_gate_handle, "lua", "send_proto", g_agent_fd, name, body)
end

function send_err(name, code, msg, session)
	local cfg = err_cfg[code] or {}
	skynet.send(".game_gated", "lua", "send_proto", g_agent_fd, "sc_err", {proto_name = name, code = cfg.id or -1, content = msg, session = session})
end

function hotfix(...)
	D("agent hotfix ", ...)
end

local function create_role(account_id, acc, device)
    local data = {
            account_id = account_id,
            nick_name = acc.name,
            avatar_id = math.random(0,10),
            sex = math.random(1, #EnumSex) - 1,
            level = 0,
            exp = 0,
            gold = 0,
            coin = 0,
            diamond = 0,
            name_modify_time = 0,
            learn_step = 0,
            extend = {},
        }

    -- if not skynet.call(".dbmgr", "sync_save_data", "t_player", data, true) then
    --     return false, "PLAYER_CREATE_DB_ERR", "数据库异常，创角失败"
    -- end

    -- snax.bind(".agentmgr", "agentmgr").post.update_player(data.account_id, data.nick_name, data.avatar_id, data.sex)

    -- 运营日志：用户ID + 账号 + 昵称 + 注册时间 + 注册渠道号 + 注册IP + 注册机器码 + 注册终端
    -- local dev = device or {}
    -- Snx.post(".productlog", "log", "RecordAccountReg", account_id, acc.name, acc.name, acc.create_time, dev.channel,
    --     dev.ip, dev.machine_code, dev.terminal)

    return data
end

local function load_acc_data(account_id)
    g_login_handle = snax.bind(".agentmgr", "agentmgr").req.get_login_handle(account_id)
    if not g_login_handle then
        return false, "PLAYER_NOT_LOGIN", "玩家未登录"
    end
    local acc = snax.bind(g_login_handle, "logind").req.get_data(account_id)
    if not acc then
        return false, "PLAYER_NOT_LOGIN", "请重新登录"
    end
    return acc
end

function load_player_data(account_id, device)
    if g_player then
        return true
    end
    local acc, code, msg = load_acc_data(account_id)
    if not acc then
        return false, code, msg
    end
    local dbmgr = snax.bind(".dbmgr", "dbmgr")
    local dbdata = dbmgr.req.query_db_data("t_player", {account_id = account_id})
    if not dbdata then
        return false, "PLAYER_LOAD_DATA_FAIL", "数据库异常"
    end
    local is_new
    local player_data
    if #dbdata <= 0 then
        local ret, code, msg = create_role(account_id, acc, device)
        if not ret then
            return false, code, msg
        end
        player_data = ret
        is_new = true
    else
        player_data = dbdata[1]
    end
    g_player = instance("player")
    g_player:load_data(acc, player_data)
    g_player_id = account_id

    g_bagmgr = instance("bagmgr", g_player_id, g_player:is_binding())
    local itemdata = dbmgr.req.query_db_data("t_item", {account_id = account_id})
    g_bagmgr:load_data(itemdata)
    g_main_bag = g_bagmgr:get_bag(0)

    if is_new then
        local init_list = GetCfg("misc")["init_item_list"]
        init_list = init_list.value or {}
        for _, v in pairs(init_list) do
            g_main_bag:add_item(v[1], v[2])
        end
    end
    return true
end