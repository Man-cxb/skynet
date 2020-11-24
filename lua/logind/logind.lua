local skynet = require "skynet"
require "skynet.manager"
local parser = require "parser"
local misc = require "misc"
require "tool"
local snax = require "snax"

local string = string
local assert = assert

local server_list = {}
local user_online = {}
local err_cfg = {}
Login_key = Login_key or {}
Tourist_id = Tourist_id or {}

local function register_proto()
    local path = "./proto"
    local map = misc.list_dir(path)
    for filename in pairs(map or {}) do
       parser.register(filename, path)
    end
end

function send_client_proto(fd, name, body)
	skynet.send(Login_gate, "lua", "send_proto", fd, name, body)
end

function send_err(fd, name, code, msg, session)
	local cfg = err_cfg[code] or {}
	skynet.send(Login_gate, "lua", "send_proto", fd, "sc_err", {proto_name = name, code = cfg.id or 0, content = msg, session = session})
end

function create_tourist()
	local account_id = math.random(1, 100000000)
	local name = "test" .. account_id
	local login_key = "qwe123" .. account_id
	local account = {
		account_id = account_id, 
		name = name, 
		passwd = "123456",
		login_key = login_key
	}
	Login_key[login_key] = account
	Tourist_id[account_id] = account
	return account
end

-- 分发协议方法，方法上面不要有accept方法，不然snaxd的id需要就对不上
function accept.dispatch_proto(proto_name, body, fd)
	D("----dispatch_proto----->>", proto_name, body, fd)
	local func = LoginProto[proto_name]
	if func then
		local ok, err = pcall(func, body, fd)
		if not ok then
			skynet.error("call function fail:", proto_name, Tbtostr(body), err)
		end
	else
		skynet.error("proto function not found:", proto_name, Tbtostr(body))
	end
end

function accept.register_gate(server, address)
	server_list[server] = address
end

function accept.logout(uid, subid)
	local u = user_online[uid]
	if u then
		skynet.error(string.format("%s@%s is logout", uid, u.server))
		user_online[uid] = nil
	end
end

function accept.login(player_id)
	local fd = skynet.call(".agentmgr", "lua", "launcher_agent", player_id)
	user_online[player_id] = fd
end



function init(server_name)
	require "loginProto"
	skynet.register(server_name)

	-- 注册协议
	register_proto()

	-- 启动网关服务
	Login_gate = skynet.newservice("gated", ".login_gated")
	skynet.call(Login_gate, "lua", "open" , {
		port = 8001,
		maxclient = 64
	})
end

function exit(...)
	print ("login server exit:ff", ...)
end

