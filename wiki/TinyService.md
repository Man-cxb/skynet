**这是一篇进阶指南，不建议对 skynet 没有太多经验的人使用。**

如果对单个简单服务的性能有特别的要求，你可以用 C 代码来编写服务，或者绕过 skynet 已有的 lua 框架调用核心 api。

比如，我们可以用以下代码实现一个等价于 examples 下 simpledb.lua 的服务：

```lua
local skynet = require "skynet"
local c = require "skynet.core"

local db = {}

local odispatch = skynet.dispatch_message

local unpack = c.unpack
local pack = c.pack
local send = c.send

function skynet.dispatch_message(prototype, msg, sz, session, source)
	if prototype == 10 then	-- 10 是 lua 消息，这里直接对这类消息进行解析。
		local command, key, value = unpack(msg, sz)
		if command == "GET" then
			send(source, 1, session, pack(db[key])) -- 1 是回应消息，此处相当于 skynet.ret 。
		elseif command == "SET" then
			local v = db[key]
			db[key] = value
			send(source, 1, session, pack(v))
		end
	else
		return odispatch(prototype, msg, sz, session, source)
	end
end

skynet.start(function() end)
```

这段代码改写了原本的 `skynet.dispatch_message` ，直接对服务接收到的消息进行处理。并直接回应请求。因为它不会在消息处理环节中对外发起请求（skynet.call），所以不必使用原有复杂的框架。