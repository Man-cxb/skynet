网关服务 (GateSever) 是游戏的接入层, 基本功能是管理客户端的连接, 分割完整的数据包, 转发给逻辑处理服务.

skynet 提供了一个通用模板 lualib/snax/gateserver.lua. 同时基于 gateserver.lua, 实现了一个网关服务 gate.lua.

TCP 是面向字节流的协议，我们需要把字节流流切割成数据包, 具体的方式见 [分包](#分包).
  

## gateserver

```lua
local gateserver = require "snax.gateserver"

local handler = {}

-- register handlers here

gateserver.start(handler)
```

这样就可以启动一个网关服务。handler 是一组自定义的消息回调函数.

```lua
function handler.connect(fd, ipaddr)
```
当一个新客户端被accept后，connect 方法会被回调。 fd 是socket句柄 (不是系统fd). ipaddr是客户端地址, 例如 "127.0.0.1:8000". 

```lua
function handler.disconnect(fd)
```
当一个连接断开，disconnect 被回调，fd 表示是哪个连接。

```lua
function handler.error(fd, msg)
```
当一个连接异常（通常意味着断开），error 被调用，除了 fd ，还会拿到错误信息 msg（通常用于 log 输出）。

```lua
function handler.command(cmd, source, ...)
```
如果你希望让服务处理一些 skynet 内部消息，可以注册 command 方法。收到 lua 协议的 skynet 消息，会调用这个方法。cmd 是消息的第一个值，通常约定为一个字符串，指明是什么指令。source 是消息的来源地址。这个方法的返回值，会通过 `skynet.ret`/`skynet.pack` 返回给来源服务。

open 和 close 这两个指令是保留的。它用于 gate 打开监听端口，和关闭监听端口。

```lua
function handler.open(source, conf)
```
如果你希望在监听端口打开的时候，做一些初始化操作，可以提供 open 这个方法。source 是请求来源地址，conf 是开启 gate 服务的参数表。

```lua
function handler.message(fd, msg, sz)
```
当一个完整的包被切分好后，message 方法被调用。这里 msg 是一个 C 指针、sz 是一个数字，表示包的长度（C 指针指向的内存块的长度）。注意：这个 C 指针需要在处理完毕后调用 C 方法 `skynet_free` 释放。（通常建议直接用封装好的库 `netpack.tostring` 来做这些底层的数据处理）；或是通过 skynet.redirect 转发给别的 skynet 服务处理。

```lua
function handler.warning(fd, size)
```
当 fd 上待发送的数据累积超过 1M 字节后，将回调这个方法。你也可以忽略这个消息。

在这些方法中，还可以调用 gateserver 模块的方法如下：
```lua
gateserver.openclient(fd)   -- 允许 fd 接收消息
```
每次收到 handler.connect 后，你都需要调用 openclient 让 fd 上的消息进入。默认状态下， fd 仅仅是连接上你的服务器，但无法发送消息给你。这个步骤需要你显式的调用是因为，或许你需要在新连接建立后，把 fd 的控制权转交给别的服务。那么你可以在一切准备好以后，再放行消息。

```lua
gateserver.closeclient(fd) -- 关闭 fd
```
通常用于主动踢掉一个连接。

## 分包
包格式：

每个包就是 2 个字节 + 数据内容。这两个字节是 Big-Endian 编码的一个数字。数据内容可以是任意字节。

所以，单个数据包最长不能超过 65535 字节。如果业务层需要传输更大的数据块，请在上层业务协议中解决。

skynet 提供一个netpack库用于处理分包问题， 位于lua-netpack.c。netpack根据包格式处理分包问题，
netpack.filter(queue, msg, size)接口，它返回一个type(“data”, “more”, “error”, “open”, “close”)代表具体IO事件，其后返回每个事件所需参数。

对于SOCKET_DATA事件，filter会进行数据分包，如果分包后刚好有一条完整消息，filter返回的type为”data”，其后跟fd msg size。
如果不止一条消息，那么数据将被依次压入queue参数中，并且仅返回一个type为”more”。 
queue是一个userdata，可以通过netpack.pop 弹出queue中的一条消息。

其余type类型”open”，”error”, “close”分别SOCKET_ACCEPT, SOCKET_ERROR, SOCKET_CLOSE事件。

netpack的使用者可以通过filter返回的type来分别进行事件处理。

netpack会尽可能多地分包，交给上层。并且通过一个哈希表保存每个套接字ID对应的粘包，在下次数据到达时，取出上次留下的粘包数据，重新分包.

### netpack api

lualib-src/lua-netpack.c 是处理这类数据包的库。

```lua
local netpack = require "skynet.netpack"
```
可以加载这个库。

* `netpack.pack(msg, [sz])` 把一个字符串（或一个 C 指针加一个长度）打包成带 2 字节包头的数据块。这个 api 返回一个lightuserdata 和一个  number 。你可以直接送到 socket.write 发送（socket.write 负责最终释放内存）。
* `netpack.tostring(msg, sz)` 把 handler.message 方法收到的 msg,sz 转换成一个 lua string，并释放 msg 占用的 C 内存。

netpack 还有一些内部 api 用于 gate server 的实现。

注意：除非你认为已经了解了细节和具备出错调试的能力，否则请不要直接使用 netpack 。

## Gate 服务器

service/gate.lua 是一个实现完整的网关服务器，同时也可以作为 snax.gateserver 的使用范例。examples/watchdog.lua 是一个可以参考的例子，它启动了一个 service/gate.lua 服务，并将处理外部连接的消息转发处理。

gate 服务启动后，并非立刻开始监听。要让 gate 服务器开启监听端口，可以通过 lua 协议向它发送一个 open 指令，附带一个启动参数表，下面是一个示范：
```lua
skynet.call(gate, "lua", "open", {
    address = "127.0.0.1", -- 监听地址 127.0.0.1
	port = 8888,    -- 监听端口 8888
	maxclient = 1024,   -- 最多允许 1024 个外部连接同时建立
	nodelay = true,     -- 给外部连接设置  TCP_NODELAY 属性
})
```

注: 这个模板不可以和 [[Socket]] 库一起使用。因为这个模板接管了 socket 类的消息。

## 其它方案

skynet 并不限制你怎样编写网关，比如你还可以使用这个模块：http://blog.codingnow.com/2016/03/skynet_tcp_package.html
