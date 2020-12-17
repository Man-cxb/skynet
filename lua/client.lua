package.cpath = "skynet/luaclib/?.so;clib/?.so"
package.path = "lua/?.lua;lua/lib/?.lua;skynet/lualib/?.lua"

if _VERSION ~= "Lua 5.3" then
	error "Use lua 5.3"
end

require "tool"
local socket = require "client.socket"
local protobuf = require "protobuf"
local parser = require "parser"
local misc = require "misc"

local fd_list = {}

local function register_proto()
    local path = "./proto"
    local map = misc.list_dir(path)
    for filename in pairs(map or {}) do
        local r = parser.register(filename, path)
        print("register_proto:", filename)
    end
end

-- 注册协议
register_proto()

-- 连接登陆服
local login_fd = assert(socket.connect("127.0.0.1", 9510))

fd_list[login_fd] = {last = ""}

local function unpack_package(text)
	local size = #text
	if size < 2 then
		return nil, text
	end
	local s = text:byte(1) * 256 + text:byte(2) -- 包头2字节包大小
	if size < s+2 then	-- 包长度小于包头标示的大小
		return nil, text
	end

	return text:sub(3,2+s), text:sub(3+s)
end

local function recv_package(fd, last)
	local result
	result, last = unpack_package(last)
	if result then
		return result, last
	end
    local r = socket.recv(fd)
	if not r then
		return nil, last
	end
	if r == "" then
		return nil, "closed"
    end
	return unpack_package(last .. r)
end

local function send_package(fd, pack)
    local package = string.pack(">s2", pack)
    print("发包长度:",#package, #pack )
	socket.send(fd, package)
end

local function send_request(fd, name, args)
    print("send_request：", fd, name, V2S(args))
	local str = protobuf.encode(name, args)
    local msg = { name = name, body = str}
    local encodemsg = protobuf.encode("proto.transfer", msg)
	send_package(fd, encodemsg)
end

local account = {}

local PlayerProto = {}
function PlayerProto:sc_login_vistor_info(fd)
    account = self
    print("账号信息:", Tbtostr(self))
end

function PlayerProto:sc_login_server_info(fd)
    -- print("登陆服信息:", Tbtostr(self))

    -- game_fd = assert(socket.connect(self.domain, self.port))
    -- fd_list[game_fd] = {last = ""}
    
    -- send_request(game_fd, "proto.cs_player_enter", {account_id = self.account_id, login_key = self.login_key})
end

function PlayerProto:sc_player_role_data(fd)
    print("玩家游戏数据:", Tbtostr(self))
end

function PlayerProto:sc_err(fd)
    print("sc_err:", Tbtostr(self))
end

function PlayerProto:default(fd, name, parm)
    print("找不到解析函数",name)
end

local function dispatch_package(fd)
	while true do
		local v
		v, fd_list[fd].last = recv_package(fd, fd_list[fd].last)
        if not v then
			return fd_list[fd].last
		end

		local transfer = protobuf.decode("proto.transfer", v)
        local msg = protobuf.decode(transfer.name, transfer.body)
        local proto_name = string.sub(transfer.name, 7)
        print("客户端收到协议：", proto_name, V2S(msg))
        local func = PlayerProto[proto_name]
        if func then
            func(msg, fd)
        else
            -- PlayerProto.default(msg, fd, transfer.name)
        end
	end
end

-- local game_fd = assert(socket.connect("127.0.0.1", 9500))
-- send_request(game_fd, "proto.cs_player_enter", {account_id = 0, login_key = ""})
send_request(login_fd, "proto.cs_login_verify", {type = 0})

while true do
    if login_fd then
	   if dispatch_package(login_fd) == "closed" then
            fd_list[login_fd] = nil
            login_fd = nil
            print("login closed!")
        end
    end
    if game_fd then
        dispatch_package(game_fd)
        -- send_request(game_fd, "proto.cs_ping", {client_time = os.time()})
    end
    if login_fd then
        -- send_request(login_fd, "proto.cs_ping", {client_time = os.time()})
    end
    socket.usleep(1000000)
end
