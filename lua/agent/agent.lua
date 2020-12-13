local skynet = require "skynet"
local snax = require "snax"
local datacenter = require "skynet.datacenter"

local err_cfg = {}

g_player_id = g_player_id
gateway = gateway
socket_fd = socket_fd
g_player = g_player

function init(player_id, gateway, socket_fd)
	D("agent start")
    require "include"
    g_player_id = player_id
    gateway = gateway
    socket_fd = socket_fd
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
	D("----dispatch_proto----->>", proto_name, body)

	local func = get_proto_func(proto_name)
	if not func then
		D("找不到协议对应的处理方法")
	end

	local ok, ret, code, msg = xpcall(func, debug.traceback, proto_name, body)
    if not ok then
		D("error_handle", debug.traceback(ret, 2))
        -- accept.send_err(name, "COM_SYS_FAIL", "协议处理失败: " .. body, proto_name.session)
        return
    end
	-- local agentmgr = snax.bind(".agentmgr", "agentmgr")
	-- local ok = agentmgr.post.test_from_agent("dsss")
	-- D("--dd-->",ok)
	-- D("--dd-->",V2S(agentmgr))

    if ret == false then
        -- accept.send_err(name, code, msg, proto_name.session)
        return
    elseif ret == true then
        -- accept.send_err(name, "SUCCESS", nil, proto_name.session)
	end
end

function response.register_agent_master(gateway_handle, fd)
    gateway = gateway_handle
    socket_fd = fd
    return true
end

function send_client_proto(name, body)
	skynet.send(gateway, "lua", "send_proto", socket_fd, name, body)
end

function accept.send_err(name, code, msg, session)
	local cfg = err_cfg[code] or {}
	skynet.send(".game_gated", "lua", "send_proto", socket_fd, "sc_err", {proto_name = name, code = cfg.id or 0, content = msg, session = session})
end

function hotfix(...)
	D("agent hotfix ", ...)
end