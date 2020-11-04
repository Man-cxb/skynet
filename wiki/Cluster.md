skynet 支持两种集群模式。

如果你仅仅是单台物理机的计算能力不足，那么最优的策略是选用更多核心的机器，在同一进程内，skynet 可以保持最高的并行能力，充分利用物理机的多核心，远比增加物理机性价比高得多。

集群并不期望完全隐藏分布式的本质。任何企图抹平服务运行位置差异的设计都需要慎重考虑，很可能存在设计问题。切记，即使在 API 使用层面看起来在不同机器和进程上的服务可以像在同一进程内的服务一样的协作，但差别并不仅仅是消息传递速度不同。搭建集群不是一件简单的事情，  skynet 本身要解决的核心问题是提供在同一机器上充分利用多核的处理能力，而并没有提供一套完善的集群方案。它只是提供了一些搭建集群所需要的必要基础设施。

master/slave 模式
====

当单台机器的处理能力达到极限后，可以考虑通过内置的 master/slave 机制来扩展。具体的配置方法见 [[Config]] 。

每个 skynet 进程都是一个 slave 节点。但其中一个 slave 节点可以通过配置 standalone 来多启动一个 cmaster 服务，用来协调 slave 组网。对于每个 slave 节点，都内置一个 harbor 服务用于和其它 slave 节点通讯。

每个 skynet 服务都有一个全网唯一的地址，这个地址是一个 32bit 数字，其高 8bit 标识着它所属 slave 的号码。即 harbor id 。在 master/slave 网络中，id 为 0 是保留的。所以最多可以有 255 个 slave 节点。

在 master/slave 模式中，节点内的消息通讯和节点间的通讯是透明的。skynet 核心会根据目的地址的 harbor id 来决定是直接投递消息，还是把消息转发给 harbor 服务。但是，两种方式的成本大为不同（可靠性也有所区别），在设计你的系统构架时，应充分考虑两者的性能差异，不应视为相同的行为。

这种模式的缺点也非常明显：它被设计为对单台物理机计算能力不足情况下的补充。所以忽略了系统一部分故障的处理机制，而把整个网络视为一体。即，整个网络中任意一个节点都必须正常工作，节点间的联系也不可断开。这就好比你一台物理机上如果插了多块 CPU ，任意一个损坏都会导致整台机器不能正常工作一样。

所以，不要把这个模式用于跨机房的组网。所有 slave 节点都应该在同一局域网内（最好在同一交换机下）。不应该把系统设计成可以任意上线或下线 slave 的模式。

slave 的组网机制也限制了这一点。如果一个 slave 意外退出网络，这个 harbor id 就被废弃，不可再使用。这样是为了防止网络中其它服务还持有这个断开的 slave 上的服务地址；而一个新的进程以相同的 harbor id 接入时，是无法保证旧地址和新地址不重复的。

----

如果你非要用 master/slave 模式来实现有一定弹性的集群。skynet 还是提供了非常有限的支持：

```lua
local harbor = require "skynet.harbor"
```

* `harbor.link(id)` 用来监控一个 slave 是否断开。如果 harbor id 对应的 slave 正常，这个 api 将阻塞。当 slave 断开时，会立刻返回。

* `harbor.linkmaster()` 用来在 slave 上监控和 master 的连接是否正常。这个 api 多用于异常时的安全退出（因为当 slave 和 master 断开后，没有手段可以恢复）。

* `harbor.connect(id)` 和 harbor.link 相反。如果 harbor id 对应的 slave 没有连接，这个 api 将阻塞，一直到它连上来才返回。

* `harbor.queryname(name)` 可以用来查询全局名字或本地名字对应的服务地址。它是一个阻塞调用。

* `harbor.globalname(name, handle)` 注册一个全局名字。如果 handle 为空，则注册自己。skynet.name 和 skynet.register 是用其实现的。

你可以利用这组 api 来解决做一次跨节点远程调用，因为节点断开而无法收到回应的问题。注意：link 和 linkmaster 都有一定的开销，所以最好在一个节点中只用少量服务调用它来监控组网状态。由它再来分发到业务层。

对于 harbor id 不可复用的问题。你可以在 [[Config]] 中将 harbor 配置为引用一个系统环境变量。然后给 skynet 编写一个启动脚本，利用一个额外的程序去某个管理器中获得尚未使用过的 harbor id ，设入环境变量，再启动 skynet 进程。这些 skynet 没有给出现成的解决方案，需要你自己来实现。

cluster 模式
=====

skynet 提供了更具弹性的集群方案。它可以和 master/slave 共存。也就是说，你可以部署多组 master/slave 网络，然后再用 cluster 将它们联系起来。当然，比较简单的结构是，每个集群中每个节点都配置为单节点模式（将 harbor id 设置为 0）。cluster 的具体设计可以参考 blog : http://blog.codingnow.com/2017/03/skynet_cluster.html 。

要使用它之前，你需要编写一个 cluster 配置文件，配置集群内所有节点的名字和对应的监听端口。并将这个文件事先部署到所有节点，并写在 [[Config]] 中。这个配置文件的范例见 examples/clustername.lua ：
```lua
db = "127.0.0.1:2528"
```

这个配置文件也可以省略，直接通过 cluster.reload 传入一个 table ，参见后面 cluster.reload 的说明 。

这表示，集群中定义有一台叫做 db 的节点，通讯端口为 127.0.0.1:2528 。

接下来，你需要在 db 的启动脚本里写上 `cluster.open "db"` 。示例见 examples/cluster1.lua 。
```lua
local skynet = require "skynet"
local cluster = require "skynet.cluster"
require "skynet.manager"

skynet.start(function()
	local sdb = skynet.newservice("simpledb")
	skynet.name(".simpledb", sdb)
	print(skynet.call(".simpledb", "lua", "SET", "a", "foobar"))
	print(skynet.call(".simpledb", "lua", "GET", "a"))
	cluster.open "db"
end)
```
它启动了 simpledb 这个服务，并起了一个本地名字 .simpledb ，然后打开了 db 节点的监听端口。

在 examples/cluster2.lua 中示范了如何调用 db 上的 .simpledb 服务。（ .simpledb 原本是一个本地服务，但通过 cluster 接口，其它节点也可以访问到它。）
```lua
local skynet = require "skynet"
local cluster = require "skynet.cluster"

skynet.start(function()
	local proxy = cluster.proxy("db", ".simpledb")
	print(skynet.call(proxy, "lua", "GET", "a"))
	print(cluster.call("db", ".simpledb", "GET", "a"))
end)
```

有两种方式可以访问到 db.simpledb ：

1. 可以通过 cluster.call(nodename, service, ...) 提起请求。这里 nodename 就是在配置表中给出的节点名。service 可以是一个字符串，或者直接是一个数字地址（如果你能从其它渠道获得地址的话）。当 service 是一个字符串时，只需要是那个节点可以见到的服务别名，可以是全局名或本地名。但更推荐是 . 开头的本地名，因为使用 cluster 模式时，似乎没有特别的理由还需要在那个节点上使用 master/slave 的架构（全局名也就没有特别的意义）。cluster.call 有可能因为 cluster 间连接不稳定而抛出 error 。但一旦因为 cluster 间连接断开而抛出 error 后，下一次调用前 cluster 间会尝试重新建立连接。此外，service 也可以是 @ 开头的字符串，表示通过[远端名字服务](#远端名字服务)注册的服务

2. 可以通过 cluster.proxy(nodename, service) 生成一个本地代理。之后，就可以像访问一个本地服务一样，和这个远程服务通讯。但向这个代理服务 send 消息，有可能因为 cluster 间的连接不稳定而丢失。详见 cluster.send 的说明。

3. 如果想单向推送消息，可以调用 cluster.send(nodename, service, ...) 。但注意，跨越节点推送消息有丢失消息的风险。因为 cluster 基于 tcp 连接，当 cluster 间的连接断开，cluster.send 的消息就可能丢失。而这个函数会立刻返回，所以调用者没有机会知道发送出错。

注意：你可以为同一个 skynet 进程（集群中的节点）配置多个通道。这种策略有时会更有效。因为一个通道仅由一条 TCP 连接保持通讯。如果你有高优先级的集群间调用需要处理，那么单独开一个通道可能更好些。

当一个名字没有配置在配置表中时，如果你向这个未命名节点发送一个请求，skynet 的默认行为是挂起，一直等到这个名字对应项的配置被更新。你可以通过配置节点名字对应的地址为 false 来明确指出这个节点已经下线。另外，可以通过在配置表中插入 `__nowaiting = true` 来关闭这种挂起行为。

Cluster 间的消息次序
=========
cluster 间的请求大部分会按调用次序排序，即先发出的请求或推送先到。但也有例外的情况。当发送包单个超过 32k 时，包会被切分成多块传输，大的包必须等到所有块传输完毕，在这种情况下，大包的请求逻辑上先发出，可能后收到。回应也有这种可能。

两个 cluster 间，如果有相互请求/推送的情况，会建立两个 tcp 连接。所以、 A 向 B 发起请求和 A 回应 B 的请求，这两类信息是不保证次序的。具体案例可见 https://github.com/cloudwu/skynet/issues/587 。

远端名字服务
=========

你可以如上面一节所述的方式，给 skynet 的服务命名，然后使用字符串来替代数字地址。同时，cluster 还提供另一套命名方案。

在本地进程内调用 `cluster.register(name [,addr])` 可以把 addr 注册为 cluster 可见的一个字符串名字 name 。如果不传 addr 表示把自身注册为 name 。

远端可以通过调用 `cluster.query(node, name)` 查询到这个名字对应的数字地址。如果名字不存在，则抛出 error 。

由于历史原因，这套命名方案和上一节的方案并存。但这节描述的方案更为推荐。因为这套命名体系仅在 cluster 的模块中存在，并不影响 skynet 底层的命名系统，更容易为日后扩展。而 skynet 底层的命名系统已不再推荐使用。

对应的，`cluster.proxy` 和 `cluster.send` 、 `cluster.call` 接口可以使用 @ 加字符串来代表通过 `cluster.register` 注册的服务，代替 service，防止因节点重启可能引起服务地址变化，导致调用失败。

Cluster 配置更新
=========

Cluster 是去中心化的，所以需要在每台机器上都放置一份配置文件（通常是相同的）。通过调用 cluster.reload 可以让本进程重新加载配置。如果你修改了每个节点名字对应的地址，那么 reload 之后的请求都会发到新的地址。而之前没有收到回应的请求还是会在老地址上等待。如果你老的地址已经无效（通常是主动关闭了进程）那么请求方会收到一个错误。

cluster.reload 也可以接收一个 table 来更新配置，如果你传入了 table，那么 table 内的数据优先级高于配置文件（配置文件被忽略）。如果一开始就没有配置文件，那么必须在使用 cluster 之前用 cluster.reload 传入最初的配置数据。

在线上产品中如何向集群中的每个节点分发新的配置文件，skynet 并没有提供方案。但这个方案一般比较容易实现。例如，你可以自己设计一个中心节点用来管理它。或者让系统管理员编写好同步脚本，并给程序加上控制指令来重载这些配置。或不依赖配置文件，而全部用 cluster.reload 来初始化。

Cluster 和 [[Snax]] 服务
=========
如果你使用 [[Snax]] 框架编写服务，且服务需要通过 Cluster 调用。那么需要做一些额外的工作。

首先，在 [[Snax]] 服务的 init 函数里，请调用一次 `snax.enablecluster()` ，否则它无法响应 Cluster 调用，而只能接收本地调用。

其次，你需要保证调用方和提供服务的机器上都能打开 snax 脚本。

如果全部条件满足，那么你可以用 `cluster.snax(node, name [,address])` 来生成一个远程 snax 服务对象。

当你只给出 node 和 name 时，相当于去目标 node 上使用 `snax.queryservice` 获取一个服务名对应的地址；如果给出了第三个参数 address ，那么 address 就是 snax 服务的地址（可以使用 @ 加字符串表示通过[远端名字服务](#远端名字服务)注册的名称），而 name 则是它的服务类型（ 绑定 snax 服务需要这个类型，具体见 snax.bind ）。