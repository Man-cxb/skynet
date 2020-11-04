![skynet logo](https://github.com/cloudwu/skynet/wiki/image/skynet_metro.jpg)

Welcome to the skynet wiki!

欢迎使用 skynet ，这是一个轻量级的为在线游戏服务器打造的框架。但从社区 [[Community]] 的反馈结果看，它也不仅仅使用在游戏服务器领域。[[Uses]] 收集了很少一部分使用 skynet 的项目，但实际项目要多得多。欢迎你把你的项目也加到这个列表中。

Skynet is a lightweight framework designed for online game servers. Although from the feedback of the [[Community]] , it's not limited as a game server framework. On the [[Uses]] page, it shows a few projects that have used or currently using Skynet, but there are way more projects than listed. And welcome to be the next user.

如果你对 skynet 毫无了解，那么可以先阅读一下 [[GettingStarted]]。由于 skynet 本身并不复杂，同时建议你阅读一下源代码。参考 [[Blogs]] 会对理解设计思路和发展历史有所帮助。还有一些同学自发编写的第三方文档 [[ThirdPartyDocument]] 供参考。

If you are new to Skynet, the best way to start is GettingStarted. And because the implementation of Skynet is not complicated, I would recommend you read source code as well. There are reference [[Blogs]] helping you understand the thoughts, design and version changes. There is also an unofficial doc [[ThirdPartyDocument]] .

[[Build]] skynet 非常简单，动手编译一个试着玩一下是个很好的开始。examples 和 test 目录下有些例子。如果你想自己动手做二次开发，你可以从理解 [[Bootstrap]] 开始，一开始不要尝试集群 [[Cluster]] 。

To [[Build]] Skynet is very simple, you can try it from downloading one and compiling it. Some examples can be found in examples and test directories. If you'd like to customize Skynet based on your own project, it's better to start from understanding [[Bootstrap]] , I would not recommend beginning with [[Cluster]] .

虽然 skynet 的核心是由 C 语言编写，但如果只是简单使用 skynet ，并不要求 C 语言基础。但你需要理解 Actor 模式的工作方式，把你的业务拆分成多个服务来协同工作。Lua 是必要的开发语言，你只需要懂得 Lua 就可以使用 [[LuaAPI]] 来完成服务间的通讯协作。另外，[[Snax]] 可能会是更简单的方式。关于服务间共享数据，除了用消息传递的方式外，还可以参考 [[ShareData]] 。skynet 已提供的功能可以参考 [[APIList]] 。

Although the core of Skynet is developed in c, you are not required to know c if you just want to use the functionalities of Skynet. What you need is to understand how Actor mode works, which breaks up your project into services and they collaborate with each other. Lua is required to develop Skynet applications, you'll need to learn how to use [[LuaAPI]] to manage the collaboration of services. In addition,  [[Snax]] is an even simpler solution. Regarding the data sharing between services,  besides using message queue, you can also take a look at [[ShareData]]. Skynet has offered a bunch of functionalities that can be found in [[APIList]].

当然只有这些仅仅可以让 skynet 内部的服务相互协作。要做到给客户端提供服务，还需要使用 [[Socket]] API ，或者使用已经编写好的 [[GateServer]] 模板解决大量客户端接入的问题。或许你还需要为 C/S 通讯制订一套通讯协议，skynet 并没有规定这个协议，可以自由选择。当然你也可以看看 [[Sproto]] 。

With the above modules I mentioned, skynet can make internal services work. To provide services to the client, you'll need to use [[Socket]] API or use [[GateServer]] to resolve high concurrent users' problems. Maybe you can make your own C/S protocol, Skynet doesn't force a specific protocol, you can come up with your own design. An example can be found at [[Sproto]].

通过这套 [[Socket]] API以及更方便的 [[SocketChannel]]（更容易实现 socket 池和断开重连） ，可以让 skynet 异步调度外部 socket 事件。对外部独立服务的访问，最好都通过这套 API 的封装。如果外部库直接调用系统的 socket ，很可能阻塞住 skynet 的工作线程，发挥不出性能。访问诸如数据库等 [[ExternalService]]，最好可以做一次封装。

With [[Socket]] API and [[SocketChannel]] , which makes it easier to implement socket pool and reconnect, you can use Skynet to call socket even asynchronously. It's best to use this API for external independent services. If using external lib to call system socket, it's very possible to be blocked on the worker threads of Skynet and couldn't make best use of Skynet. If you'd like to access [[ExternalService]] like databases, you'd better implement it by yourself.

如果你找不到你需要的外部组件的 skynet driver ，可以自己来编写，社区欢迎你的贡献。当然，你也可以写一个独立程序和外部组件沟通，再和 skynet 通讯。通讯协议可以自行定义，也可以使用 [[Http]] 协议。也可以使用 WebSocket。

If you could not find the external components you need, you can develop your own extension and you are always welcome to contribute. You can also develop your own application as a middle layer to communicate with external components and talk to Skynet. Feel free to choose your own protocol, [[Http]] or WebSocket.
