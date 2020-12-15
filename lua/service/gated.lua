require "common"
require "tool"
local skynet = require "skynet"
require "skynet.manager"
local netpack = require "skynet.netpack"
local socketdriver = require "skynet.socketdriver"
local protobuf = require "protobuf"
local snax = require "snax"
require "config"
local cs = require("queue")()

Shutting_down = Shutting_down

local user_fd = {}
local client_number = 0 -- 客户端连接数量
local queue		-- message queue
local maxclient	-- max client
local nodelay = false
local socket	-- listen socket
local gate_type, target_handle = ... -- 网关类型
local agent_handle = {}
local CMD = setmetatable({}, { __gc = function() netpack.clear(queue) end })

local function send_socket_connect(fd)
	if gate_type == "login" then
		snax.bind(target_handle, "logind").post.socket_connect(fd)
	elseif gate_type == "game" then

	end
end

local function get_player_handle(proto, fd)
    if Shutting_down then
        return false, "PLAYER_SERVER_CLOSING", "正在关服中"
	end

	local agentmgr = snax.bind(target_handle, "agentmgr")
	return cs(agentmgr.req.try_login_agent, proto.account_id, fd, skynet.self())
end

-- 协议请求
local function do_request(fd, message)
	local transfer = protobuf.decode("proto.transfer", message)
	if transfer then
		local body = protobuf.decode(transfer.name, transfer.body)
		local proto_name = string.sub(transfer.name, 7)
		-- skynet.error("gated accept proto:", proto_name, Tbtostr(body))

		if gate_type == "login" then
			snax.bind(target_handle, "logind").post.dispatch_proto(proto_name, body, fd)

		elseif gate_type == "game" then
			if agent_handle[fd] then
				snax.bind(agent_handle[fd], "agent").post.dispatch_proto(proto_name, body, fd)
			else
				if proto_name == "cs_player_enter" then
					local ok, code, handle = get_player_handle(body, fd)
					if not ok then
						CMD.send_proto(fd, "sc_err", {code = -1, proto_name = proto_name})
						return
					end
					assert(handle, "玩家未正常登陆")
					agent_handle[fd] = handle
					snax.bind(handle, "agent").post.dispatch_proto(proto_name, body, fd)
				else
					skynet.error("玩家未在登陆服登陆，不能进入游戏服")
				end
			end
		else
			skynet.error("gated type error ", gate_type, target_handle)
		end
	else
		skynet.error("gated proto ", fd, #message)
	end
end

local SOCKET_MSG = {}
local function dispatch_msg(fd, msg, sz)
	if user_fd[fd] then
		local message = netpack.tostring(msg, sz)
		local ok, err = pcall(do_request, fd, message)
		if not ok then
			skynet.error(string.format("Invalid package %s ", err))
			user_fd[fd] = nil
			socketdriver.close(fd)
		end
	else
		skynet.error(string.format("Drop message from fd (%d) : %s", fd, netpack.tostring(msg,sz)))
	end
	skynet.trash(msg, sz)
end
SOCKET_MSG.data = dispatch_msg

local function dispatch_queue()
	local fd, msg, sz = netpack.pop(queue)
	if fd then
		-- may dispatch even the handler.message blocked
		-- If the handler.message never block, the queue should be empty, so only fork once and then exit.
		skynet.fork(dispatch_queue)
		dispatch_msg(fd, msg, sz)

		for fd, msg, sz in netpack.pop, queue do
			dispatch_msg(fd, msg, sz)
		end
	end
end
SOCKET_MSG.more = dispatch_queue

function SOCKET_MSG.open(fd, addr)
	-- 客户端连接数量
	if client_number >= maxclient then
		socketdriver.close(fd)
		return
	end
	if nodelay then
		socketdriver.nodelay(fd)
	end

	user_fd[fd] = true
	client_number = client_number + 1

	socketdriver.start(fd)
	skynet.error("SOCKET_MSG.open", fd, addr)
	send_socket_connect(fd)
end

local function disconnect(fd)
	local u = user_fd[fd]
	if u then
		-- todo: socket断连处理
		skynet.error("socket close: ", fd) 
		client_number = client_number - 1
		user_fd[fd] = nil
		socketdriver.close(fd)
	end
end

function SOCKET_MSG.close(fd)
	if fd ~= socket then
		-- send_socket_status(fd, "socket_close")
		disconnect(fd)
	else
		socket = nil
	end
end

function SOCKET_MSG.error(fd, msg)
	if fd == socket then
		skynet.error("gateserver accpet error:",msg)
	else
		disconnect(fd)
	end
end

skynet.register_protocol {
	name = "socket",
	id = skynet.PTYPE_SOCKET,	-- PTYPE_SOCKET = 6
	unpack = function (msg, sz)
		return netpack.filter(queue, msg, sz)
	end,
	dispatch = function (_, _, q, _type, ...)
		queue = q
		if _type then
			local fd, msg, sz = ...
			skynet.error(string.format("gated socket msg: _type: %s, socket_fd: %s, msg: %s, sz: %s", _type, fd, msg, sz))
			SOCKET_MSG[_type](...)
		end
	end
}


function CMD.open(conf)
	assert(not socket)
	local address = conf.address or "0.0.0.0"
	local port = assert(conf.port)
	maxclient = conf.maxclient or 1024
	nodelay = conf.nodelay
	skynet.error(string.format("gate listen on %s:%d, from server:%s", address, port, gate_type))
	socket = socketdriver.listen(address, port)
	socketdriver.start(socket)
end

function CMD.close()
	assert(socket)
	socketdriver.close(socket)
end

local function send_package(fd, pack)
	local package = string.pack(">s2", pack)
	socketdriver.send(fd, package)
end

function CMD.send_proto(fd, name, proto)
	local proto_name = "proto." .. name
	-- skynet.error("gated send proto:",fd, proto_name, Tbtostr(proto))
    local str = protobuf.encode(proto_name, proto)
    local transfer = { name = proto_name, body = str, session = proto.session}
	local sendmsg = protobuf.encode("proto.transfer", transfer)
	send_package(fd, sendmsg)
end

function CMD.close_fd(fd)
	disconnect(fd)
end

function CMD.time_out(fd)
	agent_handle[fd] = nil
end

skynet.start(function()
	skynet.dispatch("lua", function (_, address, cmd, ...)
		-- skynet.error(string.format("gate dispatch lua: type: %s, param: %s", cmd, Tbtostr({...})))
		local func = CMD[cmd]
		if func then
			skynet.ret(skynet.pack(func(...)))
		else
			skynet.error("cmd not found:", cmd)
		end
	end)

	register_proto()

	skynet.register(gate_type)
end)