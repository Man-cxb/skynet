同一个 skynet 服务中的一条消息处理中，如果调用了一个阻塞 API ，那么它会被挂起。挂起过程中，这个服务可以响应其它消息。这很可能造成时序问题，要非常小心处理。

换句话说，一旦你的消息处理过程有外部请求，那么先到的消息未必比后到的消息先处理完。且每个阻塞调用之后，服务的内部状态都未必和调用前的一致（因为别的消息处理过程可能改变状态）。

skynet.queue 模块可以帮助你回避这些伪并发引起的复杂性。

```lua
local queue = require "skynet.queue"
```

这样获得的 queue 是一个函数，每次调用它都可以得到一个新的临界区。临界区可以保护一段代码不被同时运行。

```lua
local cs = queue()  -- cs 是一个执行队列

local CMD = {}

function CMD.foobar()
  cs(func1)  -- push func1 into critical section
end

function CMD.foo()
  cs(func2)  -- push func2 into critical section
end
```

比如你实现了这样一个消息分发器，支持 foobar 和 foo 两类消息。如果你使用 cs 这个 skynet.queue 创建出来的队列。那么在上面的处理流程中， func1 和 func2 这两个函数，都不会在执行过程中相互被打断。

如果你的服务收到多条 foobar 或 foo 消息，一定是处理完一条后，才处理下一条，即使 func1 或 func2 中有 skynet.call 这类的阻塞调用。一旦它们被挂起，新的消息到来后，新的处理流程会被排到 cs 队列尾，等待前面的流程执行完毕才会开始。

注：在 func1 函数内部再调用 cs 是合法的。即：

```lua

local function func2()
  -- step 3
end

local function func1()
  -- step 2
  cs(func2)
  -- step 4
end

function CMD.foobar()
  -- step 1
  cs(func1)  -- push func1 into critical section
  -- step 5
end
```

如果你这样写，每次收到 foobar 消息后，程序流程会按 step 1, step 2, step 3, step 4, step 5 这样执行，而不会死锁。

在这个过程中，如果 foobar 消息的处理流程被挂起，即使新的 foobar 消息到来，那么，新的消息会立刻执行 step 1 （因为没有被 cs 保护），然后等前一次的 step 4 结束后（step 5 不在 cs 保护中），开始新的 step 2 。


