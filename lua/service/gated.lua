local skynet = require "skynet"
require "skynet.manager"
local netpack = require "skynet.netpack"
local socketdriver = require "skynet.socketdriver"
local protobuf = require "protobuf"
local snax = require "snax"
local cs = require("queue")()
require "common"
require "tool"
require "config"

local strfmt = string.format
local strsub = string.sub
local strpack = string.pack

local shutting_down = false
local fd_list = {}
local client_number = 0 -- 客户端连接数量
local queue		-- message queue
local maxclient	-- max client
local nodelay = false
local gate_fd
local KICK_TIME = 30
local gate_type, master = ...

local function send_proto(fd, name, proto)
	local proto_name = "proto." .. name
    local str = protobuf.encode(proto_name, proto)
    local transfer = { name = proto_name, body = str, session = proto.session}
	local sendmsg = protobuf.encode("proto.transfer", transfer)
	local package = strpack(">s2", sendmsg)
	socketdriver.send(fd, package)
end

local function update_time(fd)
	if fd_list[fd] then
		fd_list[fd] = snax.time() + KICK_TIME
	end
end

local request = {}
local agent_handle = {}
function request.login(fd, proto_name, body)
	snax.bind(master, "logind").post.dispatch_proto(proto_name, body, fd)
end

function request.agent(fd, proto_name, body)
	if agent_handle[fd] then
		snax.bind(agent_handle[fd], "agent").post.dispatch_proto(proto_name, body, fd)
	else
		if proto_name ~= "cs_player_enter" then
			send_proto(fd, "sc_err", {code = -1, proto_name = proto_name, content = "请先登陆游戏"})
			return
		end

		local ok, code, handle = cs(snax.bind(master, "agentmgr").req.try_login_agent, body.account_id, fd, skynet.self())
		if not ok then
			send_proto(fd, "sc_err", {code = code or -1, proto_name = proto_name})
			return
		end
		assert(handle, "玩家未正常登陆")
		agent_handle[fd] = handle
		snax.bind(handle, "agent").post.dispatch_proto(proto_name, body, fd)
	end
end

function request.socket_disconnect(fd)
	if agent_handle[fd] then
		snax.bind(agent_handle[fd], "agent").post.socket_close()
		agent_handle[fd] = nil
	end
end

-- 协议请求
local function do_request(fd, proto_name, body)
	local func = request[gate_type]
	if func then
		func(fd, proto_name, body)
	else
		skynet.error("gate type error", gate_type)
	end
end

local SOCKET_MSG = {}
local function dispatch_msg(fd, msg, sz)
	if shutting_down then
		send_proto(fd, "sc_err", {code = -999, content = "正在关服中"})
		return
	end

	if not fd_list[fd] then
		skynet.error(strfmt("Drop message from fd (%d) : %s", fd, netpack.tostring(msg,sz)))
		skynet.trash(msg, sz)
		return
	end

	-- 解析协议
	local message = netpack.tostring(msg, sz)
	local transfer = protobuf.decode("proto.transfer", message)
	assert(transfer, strfmt("protobuf decode error: fd:%d, len:%d:", fd, #message))
	local body = protobuf.decode(transfer.name, transfer.body)
	assert(body, strfmt("protobuf decode error: fd:%d, name:%s", fd, transfer.name))
	local proto_name = strsub(transfer.name, 7)

	-- ping
	if proto_name == "cs_ping" then
		update_time(fd)
		send_proto(fd, "sc_ping", {server_time = snax.time(), client_time = body.client_time})
		return
	end

	-- 协议请求
	local ok, err = pcall(do_request, fd, proto_name, body)
	if not ok then
		skynet.error(strfmt("Invalid package %s ", err))
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

	fd_list[fd] = snax.time() + KICK_TIME
	client_number = client_number + 1

	socketdriver.start(fd)
	skynet.error("SOCKET_MSG.open", fd, addr)
end

local function disconnect(fd, reason)
	if not fd_list[fd] then
		return
	end
	skynet.error("socket close: ", fd, reason)
	socketdriver.close(fd)
	client_number = client_number - 1
	fd_list[fd] = nil

	-- 通知agent连接断开
	if gate_type == "agent" then
		request.socket_disconnect(fd)
	end
end

function SOCKET_MSG.close(fd)
	if fd ~= gate_fd then
		disconnect(fd, "client close")
	else
		gate_fd = nil
	end
end

function SOCKET_MSG.error(fd, msg)
	if fd == gate_fd then
		skynet.error("gateserver accpet error:",msg)
	else
		disconnect(fd, "socket error")
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
			xpcall(SOCKET_MSG[_type], debug.traceback, ...)
		end
	end
}

local LUA_CMD = setmetatable({}, { __gc = function() netpack.clear(queue) end })
function LUA_CMD.open(conf)
	assert(not gate_fd)
	local address = conf.address or "0.0.0.0"
	local port = assert(conf.port)
	maxclient = conf.maxclient or 1024
	nodelay = conf.nodelay
	skynet.error(strfmt("gate listen on %s:%d", address, port))
	gate_fd = socketdriver.listen(address, port)
	socketdriver.start(gate_fd)
end

function LUA_CMD.close_gate()
	assert(gate_fd)
	skynet.error("gate close")
	socketdriver.close(gate_fd)
end

function LUA_CMD.send_proto(fd, name, proto)
	send_proto(fd, name, proto)
end

function LUA_CMD.close_fd(fd, reason)
	disconnect(fd, reason)
end

function LUA_CMD.shutting_down()
	shutting_down = true
	cancel_timeout()
end

function LUA_CMD.exit_service()
	skynet.exit()
end

function on_timer()
	-- 检查连接，超时断连
	local now = snax.time()
	for fd, time in pairs(fd_list) do
		if now >= time then
			disconnect(fd, "time out")
		end
	end
end

skynet.start(function()
	skynet.dispatch("lua", function (_, address, cmd, ...)
		local func = LUA_CMD[cmd]
		if not func then
			skynet.error("gate cmd not found:", cmd)
			return
		end
		skynet.ret(skynet.pack(func(...)))
	end)

	register_proto()

	cancel_timeout = interval_timeout(100, "on_timer")
end)