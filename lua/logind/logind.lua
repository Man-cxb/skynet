require "skynet.manager"
local skynet = require "skynet"
local parser = require "parser"
local misc = require "misc"
require "tool"
require "loginProto"

local string = string
local assert = assert

local server_list = {}
local user_online = {}

local function register_proto()
    local path = "./proto"
    local map = misc.list_dir(path)
    for filename in pairs(map or {}) do
        local r = parser.register(filename, path)
        print("register_proto:", filename)
    end
end

local CMD = {}
function CMD.register_gate(server, address)
	server_list[server] = address
end

function CMD.logout(uid, subid)
	local u = user_online[uid]
	if u then
		skynet.error(string.format("%s@%s is logout", uid, u.server))
		user_online[uid] = nil
	end
end

function send_client_proto(fd, name, msg)
	skynet.send(".login_gated", "lua", "send_socket", fd, name, msg)
end

skynet.start(function()
	skynet.dispatch("lua", function(_, source, proto_name, parm, fd, ...)
		skynet.error("登陆服收到协议：", proto_name, V2S(parm), fd)
		local func = LoginProto[proto_name]
		if func then
			local ok, err, succ, code = pcall(func, parm, fd)
			if not ok then
				skynet.error(string.format("call funciton %s fail, parm: ",proto_name, V2S(parm)))
			end
			
			if type(succ) == "false" then
			elseif type(succ) == "true" then
			end
		else
			skynet.error(string.format("call funciton %s fail, parm: ",proto_name, V2S(parm)))
		end
		-- skynet.error("----------login dispatch lua",V2S(command))
		-- local f = assert(CMD[command])
		-- local msg, sz = skynet.pack(f(...))
		-- skynet.ret(msg, sz)
	end)

	skynet.register ".logind"
	-- 注册协议
	register_proto()
end)
