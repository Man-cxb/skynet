require "skynet.manager"
local skynet = require "skynet"
local netpack = require "skynet.netpack"
local socketdriver = require "skynet.socketdriver"
local protobuf = require "protobuf"
local parser = require "parser"
local misc = require "misc"
require "tool"

local user_fd = {}
local client_number = 0 -- 客户端连接数量
local queue		-- message queue
local maxclient	-- max client
local nodelay = false
local socket	-- listen socket
local gate_name

-- 协议请求
local function do_request(fd, message)
	local transfer = protobuf.decode("proto.transfer", message)
	if transfer then
		local msg = protobuf.decode(transfer.name, transfer.body)
		skynet.error("--收到协议--->", transfer.name, V2S(msg))
		return skynet.tostring(skynet.rawcall(gate_name, "lua", skynet.pack(string.sub(transfer.name, 7), msg, fd)))
	else
		skynet.error("--协议解析失败-->", fd, #message)
	end
end

local SOCKET_MSG = {}
local function dispatch_msg(fd, msg, sz)
	if user_fd[fd] then
		local message = netpack.tostring(msg, sz)
		local ok, err = pcall(do_request, fd, message)
		if not ok then
			skynet.error(string.format("Invalid package %s : %s", err, message))
			user_fd[fd] = nil
			socketdriver.close(fd)
		end
	else
		skynet.error(string.format("Drop message from fd (%d) : %s", fd, netpack.tostring(msg,sz)))
	end
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

local function disconnect(fd)
	local u = user_fd[fd]
	if u then
		-- todo: socket断连处理
		skynet.error("socket close: ", fd) 
		client_number = client_number - 1
		user_fd[fd] = nil
	end
end

function SOCKET_MSG.close(fd)
	if fd ~= socket then
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
			local fd,msg,sz = ...
			skynet.error(string.format("socket->: _type: %s, fd: %s, msg: %s, sz: %s",_type,fd,msg,sz))
			SOCKET_MSG[_type](...)
		end
	end
}

local CMD = setmetatable({}, { __gc = function() netpack.clear(queue) end })
function CMD.open(conf)
	assert(not socket)
	local address = conf.address or "0.0.0.0"
	local port = assert(conf.port)
	maxclient = conf.maxclient or 1024
	nodelay = conf.nodelay
	gate_name = conf.server_name
	skynet.error(string.format("gate listen on %s:%d, from server:%s", address, port, gate_name))
	socket = socketdriver.listen(address, port)
	socketdriver.start(socket)
end

function CMD.close()
	assert(socket)
	socketdriver.close(socket)
end

local function send_package(fd, pack)
	local package = string.pack(">s2", pack)
	skynet.error("服务端发包", fd, #package)
	socketdriver.send(fd, package)
end

function CMD.send_socket(fd, name, proto)
	local proto_name = "proto."..name
	skynet.error(">>>",fd, proto_name, V2S(proto))
    local str = protobuf.encode(proto_name, proto)
    local transfer = { name = proto_name, body = str, session = proto.session}
	local sendmsg = protobuf.encode("proto.transfer", transfer)
	send_package(fd, sendmsg)
end

local function register_proto()
    local path = "./proto"
    local map = misc.list_dir(path)
    for filename in pairs(map or {}) do
        local r = parser.register(filename, path)
        print("register_proto:", filename)
    end
end

skynet.start(function()
	skynet.dispatch("lua", function (_, address, cmd, ...)
		local f = CMD[cmd]
		skynet.error("--->>",cmd, ...)
		if f then
			skynet.ret(skynet.pack(f(...)))
		else
			skynet.error("cmd not found:", cmd)
		end
	end)

	register_proto()
	-- skynet.register ".login_gated"
end)