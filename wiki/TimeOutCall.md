skynet 针对 call 行为，只要对方没有 bug 而不返回，那么框架保证一定不会无限阻塞（返回或抛出 error ），所以没有提供超时机制。这可以减少编写代码时的心智负担。

尤其是在同一进程内，检查调用超时会掩盖 bug （被调用的服务漏写了 skynet.ret 或是设计不当，某个服务处理能力过载）。正如在普通程序中，你不会对一个库函数调用设置超时是一个道理。

但在某些特殊情况下，如果你一定要对 skynet.call 设置超时，那么可以自己做一些简单的封装：

```lua
local function timeout_call(ti, ...)
	local co = coroutine.running()
	local ret

	skynet.fork(function(...)
		ret = table.pack(pcall(skynet.call, ...))
		if co then
			skynet.wakeup(co)
		end
	end, ...)

	skynet.sleep(ti)
	co = nil	-- prevent wakeup after call
	if ret then
		if ret[1] then
			return table.unpack(ret, 1, ret.n)
		else
			error(ret[2])
		end
	else
		-- timeout
		return false
	end
end
```

