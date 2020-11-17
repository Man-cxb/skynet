require "common"
require "skynet.manager"
local skynet = require "skynet"
local parser = require "parser"
local misc = require "misc"
require "tool"
require "logind.loginProto"

local string = string
local assert = assert

local server_list = {}
local user_online = {}
local err_cfg = {}

local function register_proto()
    local path = "./proto"
    local map = misc.list_dir(path)
    for filename in pairs(map or {}) do
        local r = parser.register(filename, path)
        print("register_proto:", filename)
    end
end

function Accept.register_gate(server, address)
	server_list[server] = address
end

function Accept.logout(uid, subid)
	local u = user_online[uid]
	if u then
		skynet.error(string.format("%s@%s is logout", uid, u.server))
		user_online[uid] = nil
	end
end

function Accept.login(player_id)
	local fd = skynet.call(".agentmgr", "lua", "launcher_agent", player_id)
	user_online[player_id] = fd
end

function Accept.send_client_proto(fd, name, msg)
	skynet.send(Login_gate, "lua", "send_proto", fd, name, msg)
end

function Accept.send_err(name, code, msg, session)
	local cfg = err_cfg[code] or {}
	Accept.send_client_proto("sc_err", {proto_name = name, code = cfg.id or 0, content = msg, session = session})
end

skynet.start(function()
	skynet.dispatch("lua", Dispatch(LoginProto))

	skynet.register ".logind"

	-- 注册协议
	register_proto()

	-- 启动网关服务
	Login_gate = skynet.newservice "gated"
	skynet.call(Login_gate, "lua", "open" , {
		port = 8001,
		maxclient = 64,
		gate_type = "login"
	})
end)
