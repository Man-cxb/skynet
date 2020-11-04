skynet 默认使用了 jemalloc 作为内存管理模块，但这并非必须。jemalloc 能带来多大好处也和实际应用有关。是否连接 jemalloc 参 [[Build]] 。

skynet 实现了一个和 jemalloc 无关的 memory hook ，用来做服务占用内存的统计，可以用来在 C 层面分析是否有内存泄露。

它的原理是为每个工作线程分配一个 TLS 区，在 worker 处理服务的消息前，先设置当前服务的地址。这样在内存分配发生时就可以知道是由哪个服务分配的内存。这有一点点开销（每块内存多了几个字节，且有一些额外的运行开销），如果你计较它，可以关闭。

通常我们不太需要这个统计，因为大部分服务是用 lua 编写的，可以通过 [[DebugConsole]] 向 lua 服务索要内存使用情况。它主要用于自己编写的 Lua C 扩展库的统计。统计接口被封装为一个叫作 memory 的库供 lua 调用。或者你可以直接启动 cmemory 这个 lua 服务来输出统计信息。

注: 在 1.0 beta 之后，对于 lua 服务使用的默认分配器不再 hook 统计内存开销。它只统计 C 模块中的内存使用。如果你想修改这个行为，可以阅读 https://github.com/cloudwu/skynet/blob/master/skynet-src/malloc_hook.c

参考： https://github.com/cloudwu/skynet/blob/master/service/cmemory.lua

单个 VM 可以限制内存上限，见：https://github.com/cloudwu/skynet/blob/master/test/testmemlimit.lua

## Double Free 及内存越界检查

C 模块中，不小心对同一个内存地址调用多次 free ，或是写了多余的数据超过了申请的内存空间，都是比较常见的 bug 源。在 skynet issue 中有很多 coredump 报告都来源于直接或间接的犯了这种错误。

虽然保证不出此类 bug 并不是 skynet 框架的职责，但在这里还是提供了一个叫做 `MEMORY_CHECK` 的宏帮助检查。

在 `malloc_hook.c` 中打开注释的 `#define MEMORY_CHECK` 将在每次内存分配时都再内存块的末尾记录一个额外的 tag ，在释放的时候修改。一旦发生 double free ，将立刻发现。同时这个技巧也可以部分的检测出内存写越界。
