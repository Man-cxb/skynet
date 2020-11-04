虽然 skynet 可以尽可能的利用多核计算，但要特别小心在不能并发的流程上某个环节的处理能力过低。如果在一条处理流水线上，某个服务的处理能力明显低于前一个环节，消息就很有可能堆积在这个服务的消息队列里。

所以应该尽量避免设计出单点服务。不要把太多不相关的处理放在同一个服务内（因为单一服务的消息处理是不能并行的）。对于复杂的系统，靠猜测找到这些瓶颈非常困难，需要利用一些分析工具，然后再从设计上拆分优化。

`skynet.stat(what)` 可以返回当前服务的性能统计信息，what 可以是以下字符串。

* `"mqlen"` 消息队列中堆积的消息数量。如果消息是均匀输入的，那么 mqlen 不断增长就说明已经过载。你可以在消息的 dispatch 函数中首先判断 mqlen ，在过载发生时做一些处理（至少 log 记录下来，方便定位问题）。
* `"cpu"` 占用的 cpu 总时间。需要在 [[Config]] 配置 profile 为 true 。
* `"message"` 处理的消息条数。

profile 模块可以帮助统计一个消息处理使用的系统时间。

使用 skynet 内置的 profile 记时而不用系统带的 os.time 是因为 profile 可以剔除阻塞调用的时间，准确统计出当前 coroutine 真正的开销。

下面是一个简单的实例：
```lua
-- 一个典型的消息分发函数可以是以消息的第一个字符串参数来标识消息类型。
local command = {}

function command.foobar(...)
end

local function message_dispatch(cmd, ...)
  local f = command[cmd]
  f(...)
end
```

加上 profile 就变成了这样：
```lua
local profile = require "skynet.profile"

local ti = {}

local function message_dispatch(cmd, ...)
  profile.start()
  local f = command[cmd]
  f(...)
  local time = profile.stop()
  local p = ti[cmd]
  if p == nil then
    p = { n = 0, ti = 0 }
    ti[cmd] = p
  end
  p.n = p.n + 1
  p.ti = p.ti + time
end

-- 注册 info 函数，便于 debug 指令 INFO 查询。
skynet.info_func(function()
  return ti
end)
```

这段代码中，使用 profile.start() 和 profile.stop() 统计出其间的时间开销（返回单位是秒）。然后按消息类型分别记录在一张表 ti 中。

注：profile.start() 和 profile.stop() 必须在 skynet 线程中调用（记录当前线程），如果在 skynet [[Coroutine]] 中调用的话，请传入指定的 skynet 线程对象，通常可通过 `skynet.coroutine.thread()` 获得。

使用 skynet.info_func() 可以注册一个函数给 debug 消息处理。向这个服务发送 debug 消息 INFO 就会调用这个函数取得返回值。ps. 使用 debug console 可以主动向服务发送 debug 消息。

多服务性能跟踪
=============

skynet.trace() 在一个消息处理流程中，如果调用了这个 api ，将开启消息跟踪日志。每次调用都会生成一个唯一 tag ，所有当前执行流，和调用到的其它服务，都会计入日志中。具体解释，可以参考 https://blog.codingnow.com/2018/05/skynet_trace.html
