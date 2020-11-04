# skynet 入门 Quickstart

skynet 是一个为网络游戏服务器设计的轻量框架。但它本身并没有任何为网络游戏业务而特别设计的部分，所以尽可以把它用于其它领域。

Skynet is a lightweight framework designed for online game servers. However, it's not for online games only, you are free to use it in any area.

skynet 并不是一个开箱即用的引擎，使用它需要先对框架本身的结构有所了解，理解框架到底帮助开发者解决怎样的问题。如果你希望使用这个框架来开发网络游戏服务器，你将发现，skynet 并不会引导你把服务器搭建起来。它更像是一套工具，只有你知道你想做什么，它才会帮助你更有效率的完成。

Skynet is not an out-of-the-box engine, you'll need to get a basic idea of the Skynet framework before using it and to understand it also helps developers know what this framework can resolve. If you want to use this framework for online game servers, you'll find that Skynet wiki doesn't teach you how to build your game servers. It's more like a set of tools, and only when you know what you need,  can you achieve your goal of performance with Skynet.

理解 skynet 并不复杂，希望通过读完本篇文章，你就能掌握它。这篇文章没有提及任何 api 的具体使用方法、如何搭建 skynet 开发环境、也没有手把手示范如何写出一个简单的游戏服务器，而仅仅介绍 skynet 的基础概念。所以在真正使用 skynet 做开发时还需要参考 wiki 中的其它文档。

Skynet is not hard to understand, I'm hoping you'll know how to use it after reading this document. This wiki doc does not include how to use API, how to build Skynet, and no step-by-step instructions of writing a simple game server either, all it has is the basic concepts of Skynet. To know how to develop, please refer to other wiki documents.

## 框架 Framework

作为服务器，通常需要同时处理多份类似的业务。例如在网络游戏中，你需要同时向数千个用户提供服务；同时运作上百个副本，计算副本中的战斗、让 NPC 通过 AI 工作起来，等等。在单核年代，我们通常在 CPU 上轮流处理这些业务，给用户造成并行的假象。而现代计算机，则可以配置多达数十个核心，如何充分利用它们并行运作数千个相互独立的业务，是设计 skynet 的初衷。

An online server usually needs to process multiple services concurrently. For example, an online game server needs to provide services to thousands of players: running hundreds of instance dungeons,  calculating the battles of each instance, also making NPC work with AI, etc. At the time of the single-core processor, we usually make it running on the CPU with sliced time and providing instruction-level parallelism. For a modem computer, which may have tens of cores, Skynet aims to utilize all the cores and make them work together efficiently.

简单的 web 服务倾向于把和用户相关的状态信息（设计好数据结构）储存在数据库中，通过网络收到用户请求后，从数据库中读出关联该用户的状态信息，处理后再写回数据库。而网络游戏服务通常有更强的上下文状态，以及多个用户间更复杂的交互。如果采用相同的模式，数据库和业务处理模块间很容易出现瓶颈，这个瓶颈甚至不能通过增加一个内存 cache 层来完全解决。

For simple web applications, it's more common to put user-related status or data (pre-defined data structure) in a database, after getting the client's request, the server application loads the user's data, process it and write it back to the database. For online game applications, there will be more context and interaction between data and services. If using the same model for these two types of applications, it's easy to have a bottleneck in database and feature modules, which cannot be resolved even by adding a layer of memory cache.

在 skynet 中，用服务 (service) 这个概念来表达某项具体业务，它包括了处理业务的逻辑以及关联的数据状态。使用 skynet 实现游戏服务器时，不建议把业务状态同步到数据库中，而是存放在服务的内存数据结构里。服务、连同服务处理业务的逻辑代码和业务关联的状态数据，都是常驻内存的。如果数据库是你架构的一部分，那么大多数情况下，它扮演的是一个数据备份的角色。你可以在状态改变时，把数据推到数据库保存，也可以定期写到数据库备份。业务处理时直接使用服务内的内存数据结构。

In Skynet, Service means processing some type of application task, which includes processing the application logic and user's data. With Skynet as your game server, it's not recommended to synchronize your service data to the database, it's best to put it as a data structure in memory. Service, application logic code and game data are kept in the local memory. If a database is already a part of the game server framework, in most cases, it's used as a backup of game data. You can push your data into a database when state changes, or backup your data periodically. The application uses game data from memory directly.

由于 skynet 服务并非独立进程，所以服务间的通讯也可以被实现的高效的多。另一方面，由于这些服务同时存在于同一个 skynet 进程下，我们可以认为它们同生共死。在编写服务间协作的代码时，不用刻意考虑对方是否还活着、通讯是否可靠的问题。大多数 skynet 服务使用 lua 编写，lua 的虚拟机帮助我们隔离了服务。虽然 skynet 的基础框架设计时并没有限制服务的实现形式，理论上可以用其它语言实现 skynet 服务，但作为刚接触 skynet 的开发者，可以忽略这些细节，仅使用 Lua 做开发。

Because Skynet Service is not an independent process, so it's much more efficient to communicate between different Services. On the other hand, because these Services are running within the same Skynet process, they swim or sink together. When developing an application that requires Services collaboration, we don't need to care if the other service is still alive or if the connection is still reliable. Most of Skynet services are developed in Lua, whose virtual machine helps to isolate each service. Although when in the Skynet framework initial design, there is no limitation on how you develop services, in theory, you can develop Skynet service in other languages instead of using Lua. But if you are new to Skynet, you can skip these details and simply choose Lua.

简单说，可以把 skynet 理解为一个简单的操作系统，它可以用来调度数千个 lua 虚拟机，让它们并行工作。每个 lua 虚拟机都可以接收处理其它虚拟机发送过来的消息，以及对其它虚拟机发送消息。每个 lua 虚拟机，可以看成 skynet 这个操作系统下的独立进程，你可以在 skynet 工作时启动新的进程、销毁不再使用的进程、还可以通过调试控制台监管它们。skynet 同时掌控了外部的网络数据输入，和定时器的管理；它会把这些转换为一致的（类似进程间的消息）消息输入给这些进程。

In short, you can view Skynet as a basic operating system. It can manage thousands of Lua VM and make them work parallelly.  Each Lua VM can send messages to or receive messages from other Lua VMs. Each Lua VM can be seen as an independent process running in the Skynet OS, you can start a new process, destroy the unused processes, or you can monitor them with debugging tools when Skynet is running. Skynet manages external network data and one-shot timer and it converts these into standard messages (similar to messages between OS processes) as the input of these processes.

例如：

在网络游戏中，你可以为每个在线用户创建一个 lua 虚拟机（skynet 称之为 lua 服务），姑且把它称为 agent 。用户在不和其它用户交互而仅仅自娱自乐时，agent 完全可以满足要求。agent 在用户上线时，从数据库加载关联于它的所有数据到 lua vm 中，对用户的网络请求做出反应。当然你也可以让一个 lua 服务管理多个在线用户，每个用户是 lua 虚拟机内的一个对象。

For example:

To run an online game, you can create a Lua VM for each online user (it's called Lua Service in Skynet), let's say, Agent. If a user only plays on its own and doesn't interact with other people, one Agent can do all the work. An Agent loads all user data into Lua VM when a user is online and responds to all online requests. You can have one Lua Service manage multiple users, of course, then each user is an object of Lua VM.

你还可以用独立的服务处理网络游戏中的副本（或是战场），处理玩家和玩家间，玩家协同对战 AI 的战斗。agent 会和副本服务通过消息进行交互，而不必让用户客户端直接与副本通讯。

You can also use a single Service to process an instance dungeon (or battle), the interaction of users, or AI battles between multiple users. An agent can talk to instance dungeon with messages and client doesn't need to talk with instance dungeon directly.

这些都是具体的游戏服务器架构设计，skynet 并没有要求你应该怎么做，甚至不会建议你该怎么做。一切等你设计时做出决断。

These are very detailed server architecture design, Skynet won't make any decisions or suggestions for you. Everything is up to you.

## 网络

作为网络服务器框架，必然有封装好的网络层，对于 skynet 更是必不可少。由于 skynet 模拟了一个简单的操作系统，它最重要的工作就是调度数千个服务，如何让服务挂起时，尽量减少对系统的影响就是首要解决的问题。我们不建议你在 skynet 的服务中再使用任何直接和系统网络 api 打交道的模块，因为一旦这些模块被网络 IO 阻塞，影响的就不只是该服务本身，而是 skynet 里的工作线程了。skynet 会被配置成固定数量的工作线程，工作线程数通常和系统物理核心数量相关，而 skynet 所管理的服务数量则是动态的、远超过工作线程数量。skynet 内置的网络层可以和它的服务调度器协同工作，使用 skynet 提供的网络 API 就可以在网络 IO 阻塞时，完全释放出 CPU 处理能力。

As an online server framework, it needs an encapsulation of the network layer of course, Skynet has this as well. Because Skynet simulates a simple OS, one of the most important functionalities is to manage thousands of Services and to provide smooth services when a Service is suspended. It's not recommended to use any system network API or other network modules if you are using Skynet, the reason is if these modules have network blocking IO, it may not just affect itself but Skynet worker threads as well. Skynet is configured with a fixed number of worker threads, the amount of which is usually related to the number of physical cores, but the amount of Services that Skynet can manage is dynamic and way more than the number of worker threads. The network layer of Skynet will work with its coordinator, using Skynet network API can make the best use of CPU processing when it has network blocking IO.

skynet 有监听 TCP 连接，对外建立 TCP 连接，收发 UDP 数据包的能力。你只需要一行代码就可以监听一个端口，接收外部 TCP 连接。当有新的连接建立时，通过一个回调函数可以获得这个新连接的句柄。之后，和普通的网络应用程序一样，你可以读写这个句柄。与你写过的不同网络应用程序不太一样的是，你还可以把这个句柄转交给 skynet 中的其它服务去处理，以获得并行能力。这有点像传统 posix 系统中，接收一个新连接后，fork 一个子进程继承这个句柄来处理的模式。但不一样的是，skynet 的服务没有父子关系。
Skynet provides the functionalities of listening TCP connection, creating TCP connection, send/recv UDP packages. You only need one line of code to start listening on a port, accepting TCP connection. When there is a new connection, you can use a callback function to gain the handler of the new connection. After that, you can read/write this handler just like other network applications. The difference compared to other network applications is that you can also pass this handler to other Service of Skynet in order to achieve paralleling processing. This is similar to the traditional POSIX system when a new connection is coming, a child process will be forked to inherit this handler to do the real work. The difference here is that there is no inheritance between Services.

我们通常建议使用一个网关服务，专门监听端口，接受新连接。在用户身份确定后，再把真正的业务数据转交给特定的服务来处理。同时，网关还会负责按约定好的协议，把 TCP 连接上的数据流切分成一个个的包，而不需要业务处理服务来分割 TCP 数据流。业务处理的服务不必直接面对 socket 句柄，而由 skynet 正常的内部消息驱动即可。这样的网关服务，skynet 在发布版里就提供了一个，但它只是一个可选模块，你大可以不用它，或自己编写一个类似的服务以更符合你的项目需求。

We recommend using a gateway Service for port listening and receiving connections. Once a user's identity has been confirmed, pass user data to a specific Service for processing. At the same time, a gateway is also responsible for unpacking the data into small packages with pre-defined data protocol, Services don't need to handle the data unpacking. Application Service doesn't need to handle socket directly, just use Skynet interface for internal messaging. You can find a gateway server in Skynet code base, however, as I said it's optional not required, you can make your own based on your application requirements.

另外， skynet 的 websocket 支持目前处于实验阶段，需要切换到 websocket 分支。

In addition, the WebSocket extension in Skynet is still in an experimental stage, switch to WebSocket branch if needed.

## 客户端 Client

skynet 完全不在意如何实现客户端应用，基于 skynet 的服务器，可以用浏览器做客户端（基于 http 或 websocket 协议 通讯），也可以自己用 C / C++ / Flash / Unity3D 等等编写客户端。你可以选用 TCP socket 建立长连接通讯，也可以使用基于 http 协议的短连接，或者基于 UDP 来通讯。这都可以自由选择，skynet 没有提供直接相关的模块，都需要你自己实现。

Skynet doesn't care how the client is implemented. A Skynet server can work with web-based client (using HTTP or WebSocket protocols), or client applications written with C / C++ / Flash / Unity3D. You can also use TCP socket for persistent connections, short connections like HTTP, or event UDP connections. It's all free choices, Skynet doesn't provide persistent connections module, you'll need to write your own extension.

在 skynet 发布版的示例中，实现了一个用 C + Lua 编写的最简单的客户端 demo ，仅供参考。它基于 TCP 长连接，基础协议是用 2 字节大端字来表示每个数据包的长度，skynet 的网关服务根据这个包长度切割成业务逻辑数据包，分发给对应的内部服务处理。如果你想使用 skynet 内置的网关模块，只需要遵循这个基础的分包约定即可。

In Skynet main branch, there is a very simple client demo written in C + Lua, just for reference. It's based on TCP persistent connection, and the protocol is defined as using 2 bytes big-endian as the size of the package, Skynet gateway service splits data into application packages based on the protocol and sends it over to internal Service. If you want to use Skynet internal gateway module, just follow the rule to unpack data packages.

对于每个业务包的编码协议约定，在这个 demo 中，使用了一种叫 sproto 自定义协议，它包含在 skynet 的发布版中。demo 演示了 sproto 如何打包数据，解包数据。但是否使用 sproto 协议，skynet 没有任何约束。你也可以使用 json 或是 google protocol buffers 等，只要你知道怎样将对应的协议解析模块自己集成进 Lua 即可。建议在网关，或是使用一个独立服务，将网络消息解包翻译成 skynet 内部消息再转发给对应服务，内部服务不必关心网络层如何传输这些消息的。

For each application protocol, it's using a self-defined protocol called Sproto in this demo, which is also included in the main branch of Skynet. The demo shows how to pack/unpack data. However, it's your own decision to use Sproto protocol or not. You can use json, google protocol buffers etc, as far as you know how to integrate your own protocol interpreting module into Lua. It's recommended to use Skynet gateway or a separate Service to convert network message to Skynet internal message and then forward them to each Service, internal Services should not care about the detail of data transit in the network layer. 

## 服务 Service

skynet 的服务使用 lua 5.3 编写。只需要把符合规范的 .lua 文件放在 skynet 可以找到的路径下就可以由其它服务启动。在 skynet 的配置文件里配置了服务查询路径，以及需要启动的第一个服务，而其它服务都是由该服务直接或间接启动的。每个服务拥有一个唯一的 32bit id ，skynet 把这个 id 称为服务地址，由 skynet 框架分配。即使服务退出，该地址也会尽可能长时间的保留，以避免当消息发向一个正准备退出的服务后，新启动的服务顶替该地址，而导致消息发向了错误的实体。

Skynet Service is written in Lua 5.4. As far as you put .lua files that meet specifications in the directories where Skynet can find, it will be run by other Services. In the Skynet config file, there is a path configuration about where the Service is, also the path of the starting Service, all the other Services are running on demand. Each Service has a unique 32bit id, that is assigned by the Skynet framework and used as Service address in Skynet. Even if a Service quits, this address will be maintained for as long as it can to avoid wrong message delivery when a new Service reuses an address of an old Service.

每个服务分三个运行阶段：

Each Service has 3 stages:

首先是服务加载阶段，当服务的源文件被加载时，就会按 lua 的运行规则被执行到。这个阶段不可以调用任何有可能阻塞住该服务的 skynet api 。因为，在这个阶段中，和服务配套的 skynet 设置并没有初始化完毕。

The first stage is the Services Loading. When the Service source code is loaded, it will be executed with Lua rule. In this stage, it's not allowed to call any Skynet API that might block this Service, because, at this stage, Skynet configurations related to this Service have not been initialized yet.

然后是服务初始化阶段，由 skynet.start 这个 api 注册的初始化函数执行。这个初始化函数理论上可以调用任何 skynet api 了，但启动该服务的 skynet.newservice 这个 api 会一直等待到初始化函数结束才会返回。

The next stage is called Service Initialization, it runs all init functions registered with skynet.start API. In these init function, you can call any Skynet API in theory, however skynet.newservice API that runs this Service only returns when all init functions are done.

最后是服务工作阶段，当你在初始化阶段注册了消息处理函数的话，只要有消息输入，就会触发注册的消息处理函数。这些消息都是 skynet 内部消息，外部的网络数据，定时器也会通过内部消息的形式表达出来。

The last stage is Service Serving. If you have registered message handler function in init function, it will trigger the corresponding function when there is a message coming. All these messages are a type of Skynet internal messages, external messages and one-shot timer also work as internal messages.

从 skynet 底层框架来看，每个服务就是一个消息处理器。但在应用层看来并非如此。它是利用 lua 的 coroutine 工作的。当你的服务向另一个服务发送一个请求（即一个带 session 的消息）后，可以认为当前的消息已经处理完毕，服务会被 skynet 挂起。待对应服务收到请求并做出回应（发送一个回应类型的消息）后，服务会找到挂起的 coroutine ，把回应信息传入，延续之前未完的业务流程。从使用者角度看，更像是一个独立线程在处理这个业务流程，每个业务流程有自己独立的上下文，而不像 nodejs 等其它框架中使用的 callback 模式。

From the view of the Skynet framework infrastructure, each Service is a message processor. But that's not true from the application level. It's implemented with Lua Coroutine. When a Service sends a request (a message with session info) to another Service, that means the message has been processed, Skynet will suspend the Service(Sender). The corresponding Service(Receiver) will receive the message and reply with a response( by sending a response message type), Service (Sender) will find the suspended coroutine, deliver the message and finishes the remaining flow. From a user's perspective, it works more like a single thread that's processing a task, each task has its own context, which is not the same strategy as the callback mode used by nodejs and other frameworks.

和 erlang 不同，一个 skynet 服务在某个业务流程被挂起后，即使回应消息尚未收到，它还是可以处理其他的消息的。所以同一个 skynet 服务可以同时拥有多条业务执行线。所以，你尽可以让同一个 skynet 服务处理很多消息，它们会看起来并行，和真正分拆到不同的服务中处理的区别是，这些处理流程永远不会真正的并行，它们只是在轮流工作。一段业务会一直运行到下一个 IO 阻塞点，然后切换到下一段逻辑。你可以利用这一点，让多条业务线在处理时共享同一组数据，这些数据在同一个 lua 虚拟机下时，读写起来都比通过消息交换要廉价的多。

Not like Erlang, Skynet can still process other messages even if a request has been suspended with no responding message. So for the same Skynet Service, it can run multiple tasks. That means you can let Skynet process as many messages as possible, they look parallel from outside. The difference from processing on a difference Service is that it's not running paralleling on a physical level, it's simulated parallel processing which executes in turns in the back. A task will run to the next point of IO blocking and switches to another task. To utilize this, you can run multiple tasks with shared data within the same Lua VM, it's cheaper to use shared data compared to read/write using messages.

互有利弊的是，一旦你当前业务处理线挂起，等回应到来继续运行时，内部状态很可能被同期其它业务处理逻辑所改变，请务必小心。在 skynet api 文档中，已经注明了哪些 API 可能导致阻塞。两次阻塞 API 调用之间，运行过程是原子的，利用这个特性，会比传统多线程程序更容易编写。

The problem of this is once your task is suspended and waiting for revoke after receiving a response, the internal state might be modified by other running tasks, so be careful about this. In the doc of Skynet API, all API that might cause blocking have been notated. The call between two blocking API is atomic, it's easier to develop using this feature compared to tradition multi-threading developing.

在同一服务内还可以有多个用户线程，这些线程可以用 skynet.fork 传入一个函数启动，也可以利用 skynet 的定时器的回调函数启动。上面提到的消息处理函数其实也是一条独立的用户线程（可以理解为：响应任何一个请求，都启动了一条新的独立用户线程）。这些并不像真正操作系统的线程那样，可以利用多个核心并行运行。同一服务内的不同用户线程永远是轮流获得执行权的，每个线程都会需要一个阻塞操作而挂起让出控制权，也会在其它线程让出控制权后再延续运行。

Within the same Service, there can be multiple user threads, which can be generated with skynet.fork call, you can also start it with Skynet one-shot timer callback.  The message processing I mentioned above is also an independent user thread (it can be interpreted as: it starts a new user thread for any request). Not like the thread of operating systems, which can run on multiple cores, the user threads of the same Service are always running in order on the same core, each thread will give the control of executing by suspending on a blocking operation and will continue to execute when other threads release their control.

如果一条用户线程永远不调用阻塞 API 让出控制权，那么它将永远占据系统工作线程。skynet 并不是一个抢占式调度器，没有时间片的设计，不会因为一个工作线工作时间过长而强制挂起它。所以需要开发者自己小心，不要陷入死循环。不过，skynet 框架也做了一些监控工作，会在某个服务内的某个工作线程占据了太长时间后，以 log 的形式报告。提醒开发者修正导致死循环的 bug 。对于 lua 代码中的死循环 bug （而不是由 lua 调用的 C 模块导致的死循环）还可以由框架强制中断。具体知识可以在开发中遇到后逐步了解。

If a user thread never releases the control with blocking API, it will occupy the system worker thread forever. Skynet is not a preemptive coordinator, it doesn't include a strategy for running time control, and will not force suspending even if a task uses thread for too long. That means developers must be very careful of an infinite loop. However, Skynet framework offers some level of monitoring, which can detect if a thread in a Service is running too long and it will error out in log to remind developers to fix the infinite bug. For the infinite loop caused by Lua script (not the one caused by calling c module from Lua), there is a way to terminate it with the Skynet framework. You'll find more details in developing.

## 消息 Message

每条 skynet 消息由 6 部分构成：消息类型、session 、发起服务地址 、接收服务地址 、消息 C 指针、消息长度。

Each Skynet message contains 6 parts: message type, session, address of request Service, address of respond Service, the message C pointer, length of a message.

每个 skynet 服务都可以处理多类消息。在 skynet 中，是用 type 这个词来区分消息的。但与其说消息类型不同，不如说更接近网络端口 (port) 这个概念。每个 skynet 服务都支持 255 个不同的 port 。消息分发函数可以根据不同的 port 来为不同的消息定制不同的消息处理流程。

Each Skynet Service can process different types of messages. In Skynet, we are using "type" to tell different types of messages. However, this type more like the concept of a network port instead of a message type. Each Service can support 255 ports. Message branching function can customize message processing based on different ports.

skynet 预定义了一组消息类型，需要开发者关心的有：回应消息、网络消息、调试消息、文本消息、Lua 消息、错误。

Skynet predefined a set of message types, the ones developers care about are: Respond Message, Network Message, Debug Message, Text Message, Lua Message, Error Message.

回应消息通常不需要特别处理，它由 skynet 基础库管理，用来调度服务内的 coroutine 。当你对外发起一个请求后，对方会回应一个消息，这个消息的类型就是回应消息。发起请求方收到回应消息，会根据消息的 session 来找到之前对应的请求所在的 coroutine ，并延续它。

Respond Message usually doesn't require special handling, it's managed by Skynet lib and manages the coroutine of internal Service.  Once you send a request, the receiver will respond with a message, that is called Respond Message. When the caller receives a Respond message, it will find the original coroutine based on the Session of the message and revoke it.

网络消息也不必直接处理它，skynet 提供了 socket 封装库，封装管理这类消息，改由一组更友好的 socket api 方便使用。

Same for Network Message, Skynet provides socket lib to manages this type of message, and it has more friendly soket API.

调试消息已经被默认的 skynet 基础库处理了。它使得所有 skynet 服务都提供有一些共同的能力。比如反馈自身虚拟机所占用的内存情况、当前被挂起的任务数量、动态注入一段 lua 代码帮助调试、等等。是的、skynet 并不是通过外框架直接控制每个 lua 虚拟机，调试控制台只是通过向对应的服务发送调试消息，服务自身配合运行才得以反馈自身的状态。

Debug Message has a default handler from Skynet lib. It provides some common functionalities of all Services. For example, it offers the metrics of current Lua VM on memory usage, the number of suspended tasks, you can even put Lua script for debugging purposes, etc. Yep, Skynet doesn't have centralized control over each Lua VM, debugging controller only sends debugging messages related to Service, Service needs to customize metrics on what needs to be sent. 

真正的业务逻辑是由文本类消息和 Lua 类消息驱动的。它们的区别仅在于消息的编码形式不同，文本类消息主要方便一些底层的，直接使用 C 编写的服务处理，它就是简单字节串；而 Lua 类消息则可以序列化 Lua 的复杂数据类型。大多数情况下，我们都只使用 lua 类消息。

The real application logic is driven by Text Message and Lua Message. The difference between them is just the encoding, Text Message is good for underlying C modules, it's a simple text string, but Lua Message can be serialized to a more complicated data structure. In most cases, we only use Lua Message.

接管某类消息需要在服务的初始化过程中注册该消息的序列化及反序列化函数，以及消息回调函数。lua 类的序列化函数已经由 skynet 基础库默认注册，它们会把框架传入的消息 C 指针及长度信息转换为一组 Lua 数据。编写业务的开发者只需要注册消息回调函数即可。这个回调函数会接收到别的服务发过来的一系列 Lua 值，以及发送服务的地址和该请求的 session 号（一个 31bit 正整数）。一般我们不必关心地址和 session ，因为 skynet.ret 和 skynet.response 这两个 api 可以帮助你正确的将回应消息发还给请求者。另外，skynet 还约定，如果一个请求不需要回应（单向推送），就置 session 为 0 。

To accept some message type, it's required to register to serialize/de-serialize functions, callback functions in Service initialization. Lua serialization function has been registered as default, and it will convert C Pointer and Message Length to Lua data, to develop an application you just need to add your callback function. This callback function will receive Lua data from other Service, and the sender's address, session-id (a unique 31 bit unsigned int). We usually don't care about the address and session because API skynet.ret and skynet.response will help you pass it to the original sender. Besides, there is an unwritten rule, if you don't need a response from the receiver, you can set Session to 0.

skynet 在应用层还约定了错误类消息，不需要开发者主动处理。这类消息一般没有实际内容，只有发送源地址和 session 号。它专门用来表示某个请求发生了异常，或是某个服务即将或已经退出，无法完成请求。这类错误消息或由 skynet 基础库转换为 lua 层的 error ，抛给调用者。你可以将其理解为 RPC 调用的异常。

Skynet also has some rules of Error Message in application level, developers don't need to process it unless necessary. These type of messages usually don't have real content, it just contains the sender's address and session-id. It shows some exceptions of some requests, or some Services has terminated or about to quit and will no longer process requests. These type of Error Messages are converted to low-level Lua error by Skynet lib and raises an exception to the caller. You can see it as an RPC exception.

## 外部服务  External Service

我们应尽量可能的在同一个 skynet 进程内完成所有的业务逻辑，这样可以最大化利用系统的硬件能力，但有时又必不可少的使用一些外部进程。例如，你可以将 SQLite 封装为一个服务供其它内部服务使用；但你也可能希望使用独立的 MySQL 或是 Redis MongoDB 等独立的外部数据库服务。

We should finish all the application logic within the same Skynet process in order to make the best use of hardware functionalities, however, sometimes you have to use necessary external processes. For example, you may have an SQLite Service for other internal Services, but you may also want to use independent External Services like MySQL, Redis, MongoDB for database services.

skynet 发布版中提供了 mysql redis mongo 的驱动模块，省去了开发者自行封装的烦恼。这些驱动模块都是基于 skynet 的 socket API 实现的，可以很好的协同工作。如果你希望使用别的外部数据库，则需要自行封装。需要注意的是，大多数外部数据库的默认驱动模块都内含了网络部分，它们直接使用了系统的 socket api ，和 skynet 的网络层有一定的性能冲突。一个比较简单的兼容方案是额外再自定义一个中间进程，一边使用外部数据库的默认驱动模块，另一边用 skynet 提供的 socket channel 和 skynet 交互。

Skynet main branch provides an extension module for MySQL, Redis, MongoDB so you don't need to write your own abstraction layer. This extension module is implemented with Skynet socket API and it works pretty well. If you want to use other external databases, you'll need to develop your own extensions. Please keep in mind that, most external databases have their own network module, they use system socket API which can be conflicted with the Skynet network layer. A compatible solution is to add a middle process using socket channel as the bridge of external database socket and Skynet socket.

你还可能需要让 skynet 提供 http 协议的 web 服务，或是使用 http 协议和外部 web 服务对接。skynet 自带了 http 模块，实现一个简单的 http 服务器不会比用其它框架开发更复杂。即使用 skynet 做一个 web 服务器也可以轻松获得高性能。但是，出于简化编译依赖的想法，skynet 的默认编译脚本并没有将 openssl 链接进去，而 https 支持需要它。如果需要支持 https ，需要额外设置 `TLS_MODULE=ltls`。另外，你也可以用 nginx 制作一个 https 反向代理服务器，而不必直接使用 skynet 的 https 模块。

You may also want to use Skynet as an Http Web Server, or use HTTP protocol to talk with external Service. Skynet includes an Http module, it's not more work to develop an HTTP Server than other network frameworks. It can also be used as a high-performance web server. However, to simplify the compiling process, Skynet does not include OpenSSL by default in the build script, which is required by HTTPS. If you want to support HTTPS, you need to add  TLS_MODULE=ltls. In addition, you can use Nginx as a reverse proxy server instead of using HTTPS in Skynet.

不建议把连接管理的网关实现成一个外部服务，因为 skynet 在管理大量 TCP 连接这方面已经做的很好了。放在 skynet 内部做可以减少大量不必要的进程间数据传输。

It's not recommended to use gateway service, which manages connections, as an External Service, because Skynet is very optimized in managing TCP connections. It's better to make it a Skynet Internal Service to reduce the data transit between OS processes.

## 集群 Cluster

skynet 在最开始设计的时候，是希望把集群管理做成底层特性的。所以，每个服务的地址预留了 8bit 作为集群节点编号。最多 255 台机器可以组成一个集群，不同节点下的服务可以像同一节点进程内部那样自由的传递消息。

At the beginning of Skynet design, I was hoping to make Cluster embedded infrastructure. So 8 bit in the Service address was reserved for Cluster node. A cluster can contain at most 255 machines, a message can be transmitted over Services of different nodes just like the Service within one node.

随着 skynet 的演进和实际项目的实践，发现其实把节点间的消息传播透明化，抹平节点间和节点进程内的消息传播的区别并不是一个好主意。在同一进程内，我们可以认为服务以及服务间的通讯都是可靠的，如果自身工作所处的硬件环境正常，那么对方也一定是正常的。而当服务部署在不同进程（不同机器）上时，不可能保证完全可靠。另外一些在同一进程内可以共享访问的内存（skynet 提供的共享数据模块就基于此）也变得不可共享，这些差异无法完全被开发者忽视。

In the developing of Skynet and real-live practicing, we find that it's not a good idea to hide the fact that the messaging within the same node is different than two nodes of different machines. Within the same process, we think the communications between Services are more reliable, we can assume that if my current Service is working normally so do other Services within the same physical environments. However, when it's distributed on different processes of different machines, it's not guaranteed. In addition, memory can be shared within the same process will become unsharable as well, these cannot be ignored by developers either.

所以，虽然 skynet 可以被配置为多节点模式，但不推荐使用。

So, although Skynet is configured working as multiple nodes, it's not recommended to use.

目前推荐把不同的 skynet 服务当作外部服务来对待，skynet 发布版中提供了 cluster 模块来简化开发。

For now, we recommend treating Services from different Skynet instances as external Service, in the main branch of Skynet there is a Cluster module for quick development.
