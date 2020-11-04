当你把业务拆分到多个服务中去后，数据如何共享，可能是最易面临的问题。

最简单粗暴的方法是通过消息传递数据。如果 A 服务需要 B 服务中的数据，可以由 B 服务发送一个消息，将数据打包携带过去。如果是一份数据，很多地方都需要获得它，那么用一个服务装下这组数据，提供一组查询接口即可。[[DataCenter]] 模块对此做了简单的封装。

如果你仅仅需要一组只读的结构信息分享给很多服务（比如一些配置数据），你可以把数据写到一个 lua 文件中，让不同的服务加载它。[[Cluster]] 的配置文件就是这样做的。注意：默认 skynet 使用自带的修改版 lua ，会缓存 lua 源文件。当一个 lua 文件通过 loadfile 加载后，磁盘上的修改不会影响下一次加载。所以你需要直接用 io.open 打开文件，再用 load 加载内存中的 string 。

另一个更好的方法是使用 sharetable 模块。

ShareTable
==========

Skynet 经过修改过 Lua 虚拟机后，可以直接将一个 table 在不同的虚拟机间共享读取（但不可改变）。这个模块封装了这个特性。

* **sharetable.loadfile(filename, ...)** 从一个源文件读取一个共享表，这个文件需要返回一个 table ，这个 table 可以被多个不同的服务读取。... 是传给这个文件的参数。
* **sharetable.loadstring(filename, source, ...)** 和 loadfile 类似，但是是从一个字符串读取。
* **sharetable.loadtable(filename, tbl)** 直接将一个 table 共享。
* **sharetable.query(filename)** 以 filename 为 key 查找一个被共享的 table 。
* **sharetable.update(filenames)** 更新一个或多个 key 。

注 1：考虑到性能原因，推荐使用 sharetable.loadfile 创建这个共享表。因为使用 sharetable.loadtable 会经过一次序列化和拷贝，对于太大的表，这个过程非常的耗时。

注 2：可以多次 load 同一个 filename 的表，这样的话，对应的 table 会被更新。使用这张表的服务需要调用 update 更新。

注 3 ：一张表一旦被 query 一次，其数据的生命期将一直维持调用 query 的该服务退出。目前没有手段主动消除对一张共享表的引用。

----

以下还有一些过去曾经出现过的类似模块，仅仅因为兼容目的，暂时还在仓库中存在。

ShareData
=========

当大量的服务可能需要共享一大块并不太需要更新的结构化数据，每个服务却只使用其中一小部分。你可以设想成，这些数据在开发时就放在一个数据仓库中，各个服务按需要检索出需要的部分。

整个工程需要的数据仓库可能规模庞大，每个服务却只需要使用其中一小部分数据，如果每个服务都把所有数据加载进内存，服务数量很多时，就因为重复加载了大量不会触碰的数据而浪费了大量内存。在开发期，却很难把数据切分成更小的粒度，因为很难时刻根据需求的变化重新切分。

如果使用 [[DataCenter]] 这种中心式管理方案，却无法避免每次在检索数据时都要进行一次 RPC 调用，性能或许无法承受。

sharedata 模块正是为了解决这种需求而设计出来的。sharedata 只支持在同一节点内（同一进程下）共享数据，如果需要跨节点，需要自行同步处理。

```lua
local sharedata = require "skynet.sharedata"
```

可以引入这个模块。

* **sharedata.new(name, value)** 在当前节点内创建一个共享数据对象。
 * value 可以是一张 lua table ，但不可以有环。且 key 必须是字符串或 32bit 正整数。
 * value 还可以是一段 lua 文本代码，而 sharedata 模块将解析这段代码，把它封装到一个沙盒中运行，最终取得它返回的 table。如果它不返回 table ，则采用它的沙盒全局环境。
 * 如果 value 是一个以 @ 开头的字符串，这个字符串会被解释为一个文件名。sharedata 模块将加载该文件名指定的文件。
* **sharedata.update(name, value)** 更新当前节点的共享数据对象。
* **sharedata.delete(name)** 删除当前节点的共享数据对象。
* **sharedata.query(name)** 获取当前节点的共享数据对象。

一旦 query 到一个共享数据对象，你可以像普通 lua 表那样读取其中的数据，但禁止改写。把其中的分支赋值给 local 变量是安全的，但如果你把最终的叶节点的值取出来后，就不可能被数据源的 update 操作更新了。所以，一般你需要持有至少一级表，每次用它来索引其下的数据。

注意: query 到一个对象后，除非该对象在系统中被 delete ，暂没有任何手段可以清除本地服务中的代理对象。

一旦有人调用 sharedata.update ，所有持有这个对象的服务都会自动去数据源头更新数据。但由于这是一个并行的过程，更新并不保证立刻生效。但使用共享数据的读取方一定能在同一个时间片（单次 skynet 消息处理过程）访问到同一版本的共享数据。

更新过程是惰性的，如果你持有一个代理对象，但在更新数据后没有访问里面的数据，那么该代理对象会一直持有老版本的数据直到第一次访问。这个行为的副作用是：老版本的 C 对象会一直占用内存。如果你需要频繁更新数据，那么，为了加快内存回收，可以通知持有代理对象的服务在更新后，主动调用 sharedata.flush() 。

sharedata 是基于共享内存工作的，且访问共享对象内的数据并不会阻塞当前的服务。所以可以保证不错的性能，并节省大量的内存。

sharedata 的缺点是更新一次的成本非常大，所以不适合做服务间的数据交换。你可以考虑它的替代品：stm 模块。

sharedata 的实现是将原来的数据存储在自定义的table中，并在访问上保持原来的层级结构。自定义的table是一个userdata，其它lua VM通过自定义table的指针访问自定义table中的内容。corelib.lua中定义了userdata的元表。元表中包含__index、__len、__pairs等方法，使得访问userdata像访问原有数据一样。

如果你仅仅想利用 sharedata 模块分发配置表数据，而不关心自动更新数据、共享一部分内存。那么可以使用更高效的接口：

**sharedata.deepcopy(name, keys, ...)** 这个 api 会获得 name 对应的数据表，并根据你需要的 key 将数据做一次深拷贝，生成一个 lua table 。这样访问的效率更高。例如：sharedata.deepcopy("foobar", "x", "y") 会返回 foobar.x.y 的内容。

STM
====

STM (Software transactional memory) 模块同样基于共享内存，所以也只能用于同一个 skynet 节点内。它是一个试验性模块，不一定比消息传递的方式更好。只是提供一个新思路来进行同一节点内的服务间数据交换。

因为它不经过 skynet 的消息投递，信息传递的时效性比消息投递要好一些。但由于依旧需要在不同的 lua vm 间交换数据，序列化（使用 skynet.pack 和 skynet.unpack）必不可少。因为绕过了消息投递，它还可以用于广播。多个读取者可以同时去读一个写入者更新的数据。

stm 是以一个 C 编写的 lua 模块形式提供的。
```lua
local stm = require "skynet.stm"
```
可以引入这个模块。由于 api 多是操作 C 指针，所以调用其中的 api 上需要小心（否则会有内存泄露）。

* **stm.new(pointer, size)** 可以生成一个共享对象，生成者可以改写这个对象。pointer/size 是一个 C 指针以及长度。skynet.pack 可以正确生成它们。它返回一个 stmobj ，是一个 userdata ，lua 的 gc 会正确的回收它引用的内存。
* **stm.copy(stmobj)** 可以从一个共享对象中生成一份读拷贝。它返回一个 stmcopy ，是一个 lightuserdata 。通常一定要把这个 lightuserdata 传到需要读取这份数据的服务。随意丢弃这个指针会导致内存泄露。注：一个拷贝只能供一个读取者使用，你不可以把这个指针传递给多个服务。如果你有多个读取者，为每个人调用 copy 生成一份读拷贝。
* **stm.newcopy(stmcopy)** 把一个 C 指针转换为一份读拷贝。只有经过转换，stm 才能正确的管理它的生命期。

持有 stmobj ，则是这个共享对象的写入者。你可以用 stmobj(pointer, size) 的方式更新其中携带的信息。（这个 userdata 重载了 call 方法）。

持有 stmcopy ，则是这个共享对象的读取者。stmcpy 是用 stm.copy 生成的那个指针，传递给 stm.newcopy 构造出来的。你可以用 stmcopy(function (pointer, size [,ud]) ... end [,ud]) 的方式读出其中的数据。如果数据没有更新，将返回 false ；否则，将更新过的数据指针 ponter 以及长度，传递给传入的反序列化函数，并返回 true 以及反序列化函数的结果。

test/teststm.lua 是一个简单的使用范例。

ShareMap
========

sharemap 是对 stm 的简单应用。你可以用 sharemap 创建一个对象负责读写一张预定义的数据结构（使用 sproto 描述结果）。然后构造出读对象传递给其它服务。

当读写方修改了数据内容后，可以通过调用 commit 将修改后的副本同步给所有读取方。而读取方则需要主动调用 update 获得最新副本。

test/testsm.lua 是一个简单的使用范例。

注意：如果需要同步的数据结构比较大，这种方式的成本也会增加。因为每次 commit 都会全量序列化整个结构。









