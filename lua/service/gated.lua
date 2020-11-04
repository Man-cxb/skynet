require "skynet.manager"
local skynet = require "skynet"
local crypt = require "skynet.crypt"
local netpack = require "skynet.netpack"
local socketdriver = require "skynet.socketdriver"

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
}

local b64encode = crypt.base64encode
local b64decode = crypt.base64decode

local user_uid = {}
local user_name = {}
local user_fd = {}

local handshake = {} -- 发起连接时保存addr {addr = true}
local internal_id = 0
local client_number = 0 -- 客户端连接数量

-------------------------------------------------
local handler = {}
-- 登录服务器不允许多次登录，因此handler.login永远不会重入
function handler.login(uid, secret)
	if user_uid[uid] then
		error(string.format("%s is already login", uid))
	end

	internal_id = internal_id + 1
	local subid = internal_id	-- 不直接使用 internal_id
	-- 创建唯一的用户名
	local username = string.format("%s@%s#%s", b64encode(uid), b64encode(servername), b64encode(tostring(subid)))

	-- 启动agent
	local agent = skynet.newservice "agent"

	-- 调用agent登陆流程
	skynet.call(agent, "lua", "login", uid, subid, secret)

	local v = {
		username = username,
		agent = agent,
		uid = uid,
		subid = subid,
		secret = secret,
		version = 0,
		index = 0,
		response = {},	-- response cache
	}
	user_uid[uid] = v
	user_name[username] = v
	return subid
end

-- call by agent
function handler.logout(uid, subid)
	local u = user_uid[uid]
	if u then
		user_uid[uid] = nil
		user_name[u.username] = nil
		socketdriver.close(u.fd)
		skynet.call(".login", "lua", "logout",uid, subid)
	end
end

-- call by login server
function handler.kick(uid, subid)
	local u = user_uid[uid]
	if u then
		local username = string.format("%s@%s#%s", b64encode(uid), b64encode(servername), b64encode(tostring(subid)))
		assert(u.username == username)
		-- NOTICE: logout may call skynet.exit, so you should use pcall.
		pcall(skynet.call, u.agent, "lua", "logout")
	end
end

local function do_auth(fd, message, addr)
	local username, index, hmac = string.match(message, "([^:]*):([^:]*):([^:]*)")
	local u = user_name[username]
	if u == nil then
		return "404 User Not Found"
	end
	local idx = assert(tonumber(index))
	hmac = b64decode(hmac)

	if idx <= u.version then
		return "403 Index Expired"
	end
	local text = string.format("%s:%s", username, index)
	local v = crypt.hmac_hash(u.secret, text)	-- equivalent to crypt.hmac64(crypt.hashkey(text), u.secret)
	if v ~= hmac then
		return "401 Unauthorized"
	end

	u.version = idx
	u.fd = fd
	u.ip = addr
	user_fd[fd] = u
	return "200 OK"
end

local function do_request(fd, message)
	local u = assert(user_fd[fd], "invalid fd")
	local session = string.unpack(">I4", message, -4)
	message = message:sub(1,-5)

	local function request_handler(username, msg)
		return skynet.tostring(skynet.rawcall(u.agent, "client", msg))
	end

	-- 注意：这里是 yield， socket有可能断开
	local ok, result = pcall(request_handler, u.username, message)
	if not ok then
		skynet.error(result)
		result = string.pack(">BI4", 0, session)
	else
		result = result .. string.pack(">BI4", 1, session)
	end

	local s = string.pack(">s2", result or "")
	socketdriver.send(fd, s)
end

------------------------------------------------------
local queue		-- message queue
local CMD = setmetatable({}, { __gc = function() netpack.clear(queue) end })
local maxclient	-- max client
local nodelay = false
local socket	-- listen socket

function CMD.open(source, conf)
	assert(not socket)
	local address = conf.address or "0.0.0.0"
	local port = assert(conf.port)
	maxclient = conf.maxclient or 1024
	nodelay = conf.nodelay
	skynet.error(string.format("gate listen on %s:%d", address, port))
	socket = socketdriver.listen(address, port)
	socketdriver.start(socket)

	servername = assert(conf.servername)
	skynet.call(".login", "lua", "register_gate", servername, skynet.self())
end

function CMD.close()
	assert(socket)
	socketdriver.close(socket)
end

local SOCKET_MSG = {}

local function dispatch_msg(fd, msg, sz)
	-- if connection[fd] then
	if user_fd[fd] then
		local message = netpack.tostring(msg, sz)
		local addr = handshake[fd]
		if addr then
			-- atomic , no yield
			local ok, result = pcall(do_auth, fd, message, addr)
		
			skynet.error("gate auth send ", fd, result)
			socketdriver.send(fd, netpack.pack(result))
		
			if not ok then
				-- connection[fd] = nil
				user_fd[fd] = nil
				socketdriver.close(fd)
			end
			handshake[fd] = nil
		else
			local ok, err = pcall(do_request, fd, message)
			-- not atomic, may yield
			if not ok then
				skynet.error(string.format("Invalid package %s : %s", err, message))
				-- connection[fd] = nil
				user_fd[fd] = nil
				socketdriver.close(fd)
			end
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
	-- connection[fd] = true
	client_number = client_number + 1

	handshake[fd] = addr
	socketdriver.start(fd)
	skynet.error("SOCKET_MSG.open", fd, addr)
end

local function disconnect(fd)
	handshake[fd] = nil
	local u = user_fd[fd]
	if u then
		skynet.call(u.agent, "lua", "afk")
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

skynet.start(function()
	skynet.dispatch("lua", function (_, address, cmd, ...)
		local f = CMD[cmd]
		skynet.error("--gate dispatch->>:", cmd)
		if f then
			skynet.ret(skynet.pack(f(address, ...)))
		else
			skynet.ret(skynet.pack(handler[cmd](...)))
		end
	end)

	skynet.register ".gate"
end)