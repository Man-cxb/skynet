在和客户端通讯时，需要制订一套通讯协议。 skynet 并没有规定任何通讯协议，所以你可以自由选择。

sproto 是一套由 skynet 自身提供的协议，并没有特别推荐使用，只是一个选项。[sproto 有一个独立项目存在](https://github.com/cloudwu/sproto) 。同时也复制了一份在 skynet 的源码库中。

它类似 google protobuffers ，但设计的更简单，也更利于 lua 使用。同时还提供了一套简单的 rpc 方案。

关于 sproto 的编码协议，在 sproto 的 readme 中已有详述，下面介绍其 RPC 部分。

RPC
====

首先我们需要定义一个消息包的主体格式。它必须有一个叫 type 的字段，描述 RPC 到底是哪一条消息。还需要有一个 session 字段来表示回应消息的对应关系。通常这两个字段都被定义成 integer 。

```
.package {
	type 0 : integer
	session 1 : integer
}
```

使用 sproto 的 rpc 框架，每条消息都会以这条消息开头，接上真正的消息内容；连接在一起后用 sproto 的 0-pack 方式打包。注意，这个数据包并不包含长度信息，所以真正在网络上传输，还需要添加长度信息，方便分包。当然，如果你使用 skynet 的 gate 模块的话，约定了以两字节大端表示的长度加内容的方式分包。

构造一个 sproto rpc 的消息处理器，应使用：
```lua
local host = sproto:host(packagename)  -- packagename 默认值为 "package" 即对应前面的 .package 类型。你也可以起别的名字。
```
这条调用会返回一个 host 对象，用于处理接收的消息。
```lua
host:dispatch(msgcontent)
```
用于处理一条消息。这里的 msgcontent 也是一个字符串，或是一个 userdata（指针）加一个长度。它应符合上述的以 sproto 的 0-pack 方式打包的包格式。

dispatch 调用有两种可能的返回类别，由第一个返回值决定：

* REQUEST : 第一个返回值为 "REQUEST" 时，表示这是一个远程请求。如果请求包中没有 session 字段，表示该请求不需要回应。这时，第 2 和第 3  个返回值分别为消息类型名（即在 sproto 定义中提到的某个以 . 开头的类型名），以及消息内容（通常是一个 table ）；如果请求包中有 session 字段，那么还会有第 4 个返回值：一个用于生成回应包的函数。

* RESPONSE ：第一个返回值为 "RESPONSE" 时，第 2 和 第 3 个返回值分别为 session 和消息内容。消息内容通常是一个 table ，但也可能不存在内容（仅仅是一个回应确认）。

```lua
local sender = host:attach(sp)  -- 这里的 sp 是向外发出的消息协议定义。
```
attach 可以构造一个发送函数，用来将对外请求打包编码成可以被 dispatch 正确解码的数据包。

这个 sender 函数接受三个参数（name, args, session）。name 是消息的字符串名、args 是一张保存用消息内容的 table ，而 session 是你提供的唯一识别号，用于让对方正确的回应。 当你的协议不规定需要回应时，session 可以不给出。同样，args 也可以为空。

Sproto Loader
=====

由于 skynet 采用的是多 lua 虚拟机。如果在每个 VM 里都加载相同的 sproto 协议定义就略显浪费。所以 skynet 还提供了一个叫 sprotoloader 的模块来共享它们。

其实现原理是在 C 模块中提供了 16 个全局的 slot ，可以通过 sprotoloader.register 或 sprotoloader.save 在初始化时，加载需要的协议，并保存在这些 slot 里。通常我们只需要两个 slot ，一个用于保存客户端到服务器的协议组，另一个用于保存服务器到客户端的协议组。分别位于 slot 1 和 2 。

这样，在每个 vm 内，都可以通过 sprotoloader.load 把协议加载到 vm 中。

注意：这套 api 并非线程安全。所以必须自行保证在初始化完毕后再做 load 操作。（load 本身是线程安全的）。

-----
具体的使用范例，可以参考 examples 下的 agent.lua 以及 examples 下的 client.lua 。理解 RPC 是如何工作的。
