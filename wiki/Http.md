skynet 从 v0.5.0 开始提供了简单的 http 服务器的支持。`skynet.httpd` 是一个独立于 skynet 的，用于 http 协议解析的库，它本身依赖 socket api 的注入。使用它，你需要把读写 socket 的 API 封装好，注入到里面就可以工作。

`skynet.sockethelper` 模块将 skynet 的 [[Socket]] API 封装成 `skynet.httpd` 可以接受的形式：阻塞读写指定的字节数、网络错误以异常形式抛出。

下面是一个简单的范例：

```lua
-- examples/simpleweb.lua

local skynet = require "skynet"
local socket = require "skynet.socket"
local httpd = require "http.httpd"
local sockethelper = require "http.sockethelper"
local urllib = require "http.url"
local table = table
local string = string

local mode = ...

if mode == "agent" then

local function response(id, ...)
	local ok, err = httpd.write_response(sockethelper.writefunc(id), ...)
	if not ok then
		-- if err == sockethelper.socket_error , that means socket closed.
		skynet.error(string.format("fd = %d, %s", id, err))
	end
end

skynet.start(function()
	skynet.dispatch("lua", function (_,_,id)
		socket.start(id)  -- 开始接收一个 socket
		-- limit request body size to 8192 (you can pass nil to unlimit)
		-- 一般的业务不需要处理大量上行数据，为了防止攻击，做了一个 8K 限制。这个限制可以去掉。
		local code, url, method, header, body = httpd.read_request(sockethelper.readfunc(id), 8192)
		if code then
			if code ~= 200 then  -- 如果协议解析有问题，就回应一个错误码 code 。
				response(id, code)
			else
				-- 这是一个示范的回应过程，你可以根据你的实际需要，解析 url, method 和 header 做出回应。
				local tmp = {}
				if header.host then
					table.insert(tmp, string.format("host: %s", header.host))
				end
				local path, query = urllib.parse(url)
				table.insert(tmp, string.format("path: %s", path))
				if query then
					local q = urllib.parse_query(query)
					for k, v in pairs(q) do
						table.insert(tmp, string.format("query: %s= %s", k,v))
					end
				end
				response(id, code, table.concat(tmp,"\n"))
			end
		else
			-- 如果抛出的异常是 sockethelper.socket_error 表示是客户端网络断开了。
			if url == sockethelper.socket_error then
				skynet.error("socket closed")
			else
				skynet.error(url)
			end
		end
		socket.close(id)
	end)
end)

else

skynet.start(function()
	local agent = {}
	for i= 1, 20 do
		-- 启动 20 个代理服务用于处理 http 请求
		agent[i] = skynet.newservice(SERVICE_NAME, "agent")  
	end
	local balance = 1
	-- 监听一个 web 端口
	local id = socket.listen("0.0.0.0", 8001)  
	socket.start(id , function(id, addr)  
		-- 当一个 http 请求到达的时候, 把 socket id 分发到事先准备好的代理中去处理。
		skynet.error(string.format("%s connected, pass it to agent :%08x", addr, agent[balance]))
		skynet.send(agent[balance], "lua", id)
		balance = balance + 1
		if balance > #agent then
			balance = 1
		end
	end)
end)

end
```

这个 httpd 模块最初是用于服务器内部管理，以及和其它平台对接。所以只提供了最简单的功能。如果是重度的业务要使用，可以考虑再其上做进一步的开发。


httpc
=====
skynet 提供了一个非常简单的 http 客户端模块。你可以用:

`httpc.request(method, host, uri, recvheader, header, content)`

来提交一个 http 请求，其中 
* method 是 "GET" "POST" 等。
* host 为目标机的地址
* uri 为请求的 URI
* recvheader 可以是 nil 或一张空表，用于接收回应的 http 协议头。
* header 是自定义的 http 请求头。注：如果 header 中没有给出 host ，那么将用前面的 host 参数自动补上。
* content 为请求的内容。

它返回状态码和内容。如果网络出错，则抛出 error 。

`httpc.dns(server, port)`

可以用来设置一个异步查询 dns 的服务器地址。如果你不给出地址，那么将从 `/etc/resolv.conf` 查找地址。如果你没有调用它设置异步 dns 查询，那么 skynet 将在网络底层做同步查询。这很有可能阻塞住整个 skynet 的网络消息处理（不仅仅阻塞单个 skynet 服务）。

另外，httpc 还提供了简单的 `httpc.get` 以及 `httpc.post` 的封装，具体可以参考源代码。

如果有https的需求，可使用 [lua-webclient](http://github.com/dpull/lua-webclient) 它是libcurl multi interface的简单封装，支持单线程，非阻塞的大量http、https请求。

httpc 可以通过设置 httpc.timeout 的值来控制超时时间。时间单位为 1/100 秒。

https
=====
默认skynet是不开启`https`支持，如要使用`https`，需在makefile中开启build `ltls.so`(详情参阅FAQ)。

## https client
发起https请求，使用的依然是`httpc`模块，只需`host`参数中添加上`protocol`声明， `httpc.request('GET', 'https://google.com', ...)`即为发起https请求。`protocol`默认为`http`。 

## https server
详情参阅 [simpleweb.lua中https的实现](https://github.com/cloudwu/skynet/blob/master/examples/simpleweb.lua#L32-L50)。