package.cpath = "skynet/luaclib/?.so"

local socket = require "client.socket"
local crypt = require "client.crypt"

if _VERSION ~= "Lua 5.3" then
	error "Use lua 5.3"
end

local token = {
	server = "sample",
	user = "hello",
	pass = "password",
}

local function unpack_package(text)
	local size = #text
	if size < 2 then
		return nil, text
	end
	local s = text:byte(1) * 256 + text:byte(2)
	if size < s+2 then
		return nil, text
	end
	return text:sub(3,2+s), text:sub(3+s)
end

local function unpack_line(text)
	local from = text:find("\n", 1, true)
    if from then
		return text:sub(1, from-1), text:sub(from+1)
	end
	return nil, text
end

local function send_socket(fd, text)
    print("send_socket: ", fd, text)
    socket.send(fd, text)
end

local function read_socket(fd, unpack_func)
    while true do
        local r = socket.recv(fd)
        if r then
            if r == "" then
                error "Server closed"
            end
            local s = unpack_func(r)
            print("read_socket:", s)
            return s
        end
        socket.usleep(100)
    end
end

local function encode_token(token)
	return string.format("%s@%s:%s",
		crypt.base64encode(token.user),
		crypt.base64encode(token.server),
		crypt.base64encode(token.pass))
end

local function send_request(fd, v, session)
	local size = #v + 4
	local msg = string.pack(">I2", size)..v..string.pack(">I4", session)
    send_socket(fd, msg)
	return v, session
end

local function recv_response(v)
	local size = #v - 5
	local content, ok, session = string.unpack("c"..tostring(size).."B>I4", v)
	return ok ~=0 , content, session
end

----------------------------------------------------
-- 连接登陆服
local fd = assert(socket.connect("127.0.0.1", 8001))
print("connect 8001 fd ", fd)

-- 获得服务端端验证码
local challenge = crypt.base64decode(read_socket(fd, unpack_line))

-- 创建客户端key，并发送给服务端
local clientkey = crypt.randomkey()
send_socket(fd, crypt.base64encode(crypt.dhexchange(clientkey)) .. "\n")

-- 收到服务端key，和客户端key算出密钥
local secret = crypt.dhsecret(crypt.base64decode(read_socket(fd, unpack_line)), clientkey)
print("sceret is ", crypt.hexencode(secret))

-- 使用 服务端验证码 + 算出的密钥 创建hmac，并发送给服务端
local hmac = crypt.hmac64(challenge, secret)
send_socket(fd, crypt.base64encode(hmac) .. "\n")

-- 使用协商成功的密钥加密账号密码发送给服务端
local etoken = crypt.desencode(secret, encode_token(token))
send_socket(fd, crypt.base64encode(etoken) .. "\n")

local result = read_socket(fd, unpack_line)
print("登陆结果：", result)

local code = tonumber(string.sub(result, 1, 3))
assert(code == 200)
-- 关闭登陆服的fd
socket.close(fd)

local subid = crypt.base64decode(string.sub(result, 5))

print("login ok, subid=", subid)

-- 开始连接游戏服
local text = "echo"
local index = 1

fd = assert(socket.connect("127.0.0.1", 8888))
print("connect 8888 fd ", fd)

-- 加密账户信息，发送到服务端
local handshake = string.format("%s@%s#%s:%d", crypt.base64encode(token.user), crypt.base64encode(token.server),crypt.base64encode(subid) , index)
local hmac = crypt.hmac64(crypt.hashkey(handshake), secret)
local package = string.pack(">s2", handshake .. ":" .. crypt.base64encode(hmac))
send_socket(fd, package)

print("===>",send_request(fd, text, 0))
-- don't recv response
-- print("<===",recv_response(read_socket(fd, unpack_package)))

print("disconnect")
socket.close(fd)

index = index + 1

print("connect again")
fd = assert(socket.connect("127.0.0.1", 8888))

local handshake = string.format("%s@%s#%s:%d", crypt.base64encode(token.user), crypt.base64encode(token.server),crypt.base64encode(subid) , index)
local hmac = crypt.hmac64(crypt.hashkey(handshake), secret)

local package = string.pack(">s2", handshake .. ":" .. crypt.base64encode(hmac))
send_socket(fd, package)

print(read_socket(fd, unpack_package))
print("===>",send_request(fd, "fake", 0))	-- request again (use last session 0, so the request message is fake)
print("===>",send_request(fd, "again", 1))	-- request again (use new session)
print("<===",recv_response(read_socket(fd, unpack_package)))
print("<===",recv_response(read_socket(fd, unpack_package)))


print("disconnect")
-- socket.close(fd)

