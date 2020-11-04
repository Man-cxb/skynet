由于 skynet 框架的消息处理使用了 coroutine ，所以不可以将 lua 原本的 coroutine api 直接和 skynet 服务混用。否则，skynet 的阻塞 API （见 [[LuaAPI]]）将调用 `coroutine.yield` 而使得用户写的 coroutine.resume 有不可预期的返回值，并打乱 skynet 框架本身的处理流程。

通常，你可以使用 `skynet.fork` ，`skynet.wait`，`skynet.wakeup` 在 skynet 服务中创建用户级线程。

如果你有其它原因想使用 coroutine ，那么可以使用 `skynet.coroutine` 模块。该模块的 API 含义和 Lua 原生的 coroutine 基本一致，所以一般可以这样使用：
```lua
local coroutine = require "skynet.coroutine"
```

该模块增加了一个 API ：
`skynet.coroutine.thread(co)` ，它返回两个值，第一个是该 co 是由哪个 skynet thread 间接调用的。如果 co 就是一个 skynet thread ，那么这个值和 `coroutine.running()` 一致，且第二个返回值为 true ，否则第二个返回值为 false 。这第二个返回值可以用于判断一个 co 是否是由 `skynet.coroutine.create` 或 `skynet.coroutine.wrap` 创建出来的 coroutine 。

这里的 co 的默认值为 `coroutine.running()`。

限制
====

如果你没有调用 `skynet.coroutine.resume` 启动一个 skynet coroutine 而调用了 `skynet.coroutine.yield` 的话，会返回错误。

你可以在不同的 skynet 线程（由 `skynet.fork` 创建，或由一条新的外部消息创建出的处理流程）中 resume 同一个 skynet coroutine 。但如果该 coroutine 是由 skynet 框架（通常是调用了 skynet 的阻塞 API）而不是 `skynet.coroutine.yield` 挂起的话，会被视为 normal 状态，resume 出错。

注：对于挂起在 skynet 框架下的 coroutine ，skynet.coroutine.status 会返回 "blocked" 。




