local skynet = require "skynet"
require "skynet.manager"
local netpack = require "skynet.netpack"
local socketdriver = require "skynet.socketdriver"
local protobuf = require "protobuf"
local snax = require "snax"
-- local cs = require("queue")()
require "common"
require "tool"
require "config"

local strfmt = string.format
local strsub = string.sub
local strpack = string.pack

local shutting_down = false
local user_fd = {}
local client_number = 0 -- 客户端连接数量
local queue		-- message queue
local maxclient	-- max client
local nodelay = false
local gate_fd


function send_proto(fd, name, proto)
	local proto_name = "proto." .. name
    local str = protobuf.encode(proto_name, proto)
    local transfer = { name = proto_name, body = str, session = proto.session}
	local sendmsg = protobuf.encode("proto.transfer", transfer)
	local package = strpack(">s2", sendmsg)
	socketdriver.send(fd, package)
end

-- 具体协议请求 子类继承 todo
function do_request(fd, proto_name, body)

end

local SOCKET_MSG = {}
local function dispatch_msg(fd, msg, sz)
	if not user_fd[fd] then
		skynet.error(strfmt("Drop message from fd (%d) : %s", fd, netpack.tostring(msg,sz)))
		skynet.trash(msg, sz)
		return
	end

	if shutting_down then
		send_proto(fd, "sc_err", {code = -999, content = "正在关服中"})
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
		-- todo
		return
	end

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

	user_fd[fd] = true
	client_number = client_number + 1

	socketdriver.start(fd)
	skynet.error("SOCKET_MSG.open", fd, addr)
end

local function disconnect(fd, reason)
	if not user_fd[fd] then
		return
	end
	skynet.error("socket close: ", fd, reason)
	socketdriver.close(fd)
	client_number = client_number - 1
	user_fd[fd] = nil
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
			-- local fd, msg, sz = ...
			-- skynet.error(strfmt("gated socket msg: _type: %s, socket_fd: %s, msg: %s, sz: %s", _type, fd, msg, sz))
			SOCKET_MSG[_type](...)
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

function LUA_CMD.close_game()
	shutting_down = true
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
end)